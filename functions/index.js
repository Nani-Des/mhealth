const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.onBookingCreated = functions.firestore
  .document("Bookings/{userId}/UserBookings/{bookingId}")
  .onCreate(async (snap, context) => {
    console.log("onBookingCreated: Started execution for bookingId: ", context.params.bookingId);
    const booking = snap.data();
    const userId = context.params.userId;
    const doctorId = booking.doctorId;

    // Fetch user and doctor data
    let userDoc, doctorDoc;
    try {
      userDoc = await admin.firestore().collection("Users").doc(userId).get();
      doctorDoc = await admin.firestore().collection("Users").doc(doctorId).get();
    } catch (error) {
      console.error(`onBookingCreated: Error fetching user/doctor docs - userId: ${userId}, doctorId: ${doctorId}, error:`, error);
      return null;
    }

    if (!userDoc.exists) {
      console.error(`onBookingCreated: User not found: ${userId}`);
      return null;
    }
    if (!doctorDoc.exists) {
      console.error(`onBookingCreated: Doctor not found: ${doctorId}`);
      return null;
    }

    const userName = userDoc.data().name || "User";
    const doctorFcmToken = doctorDoc.data().fcmToken;

    if (!doctorFcmToken) {
      console.error(`onBookingCreated: No FCM token for doctor ${doctorId}`);
      return null;
    }

    const message = {
      token: doctorFcmToken,
      notification: {
        title: "New Booking Request",
        body: `You have a new booking request from ${userName} for ${new Date(booking.bookingDate.seconds * 1000).toLocaleString()}.`,
      },
      data: {
        type: "new_booking",
        userId: userId,
        doctorId: doctorId,
        bookingDate: booking.bookingDate.seconds.toString(),
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            contentAvailable: true,
          },
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);
      console.log(`onBookingCreated: Sent new_booking notification to doctor ${doctorId}:`, response);
      return null;
    } catch (error) {
      console.error(`onBookingCreated: Error sending notification to doctor ${doctorId}:`, error);
      return null;
    }
  });

exports.onBookingStatusUpdated = functions.firestore
  .document("Bookings/{userId}/UserBookings/{bookingId}")
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    const userId = context.params.userId;
    const doctorId = newData.doctorId;

    if (newData.status !== oldData.status) {
      console.log(`onBookingStatusUpdated: Status changed for bookingId: ${context.params.bookingId}, new status: ${newData.status}`);
      let userDoc;
      try {
        userDoc = await admin.firestore().collection("Users").doc(userId).get();
      } catch (error) {
        console.error(`onBookingStatusUpdated: Error fetching user ${userId}:`, error);
        return null;
      }

      if (!userDoc.exists) {
        console.error(`onBookingStatusUpdated: User not found: ${userId}`);
        return null;
      }

      const userFcmToken = userDoc.data().fcmToken;
      if (!userFcmToken) {
        console.error(`onBookingStatusUpdated: No FCM token for user ${userId}`);
        return null;
      }

      let title, body, type;
      if (newData.status === "Active") {
        title = "Booking Accepted";
        body = `Your booking with doctor for ${new Date(newData.bookingDate.seconds * 1000).toLocaleString()} has been accepted.`;
        type = "booking_accepted";
      } else if (newData.status === "Cancelled") {
        title = "Booking Cancelled";
        body = `Your booking with doctor for ${newData.bookingDate.seconds * 1000).toLocaleString()} has been cancelled.`;
        type = "booking_cancelled";
      } else {
        console.log(`onBookingStatusUpdated: No notification needed for status: ${newData.status}`);
        return null;
      }

      const message = {
        token: userFcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: type,
          userId: userId,
          doctorId: doctorId,
          bookingDate: newData.bookingDate.seconds.toString(),
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              contentAvailable: true,
            },
          },
        },
      };

      try {
        const response = await admin.messaging().send(message);
        console.log(`onBookingStatusUpdated: Sent ${type} notification to user ${userId}:`, response);
        return null;
      } catch (error) {
        console.error(`onBookingStatusUpdated: Error sending ${type} notification to user ${userId}:`, error);
        return null;
      }
    }
    return null;
  });

exports.sendBookingReminders = functions.pubsub.schedule("every 24 hours").onRun(async () => {
  console.log("sendBookingReminders: Started execution");
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  tomorrow.setHours(0, 0, 0, 0);
  const tomorrowEnd = new Date(tomorrow);
  tomorrowEnd.setHours(23, 59, 59, 999);

  let bookingsSnapshot;
  try {
    bookingsSnapshot = await admin.firestore()
      .collectionGroup("UserBookings")
      .where("status", "==", "Active")
      .where("bookingDate", ">=", tomorrow)
      .where("bookingDate", "<=", tomorrowEnd)
      .get();
  } catch (error) {
    console.error("sendBookingReminders: Error fetching bookings:", error);
    return null;
  }

  if (bookingsSnapshot.empty) {
    console.log("sendBookingReminders: No bookings found for tomorrow");
    return null;
  }

  for (const doc of bookingsSnapshot.docs) {
    const booking = doc.data();
    const userId = doc.ref.parent.parent.id;

    let userDoc;
    try {
      userDoc = await admin.firestore().collection("Users").doc(userId).get();
    } catch (error) {
      console.error(`sendBookingReminders: Error fetching user ${userId}:`, error);
      continue;
    }

    if (!userDoc.exists) {
      console.error(`sendBookingReminders: User not found: ${userId}`);
      continue;
    }

    const userFcmToken = userDoc.data().fcmToken;
    if (!userFcmToken) {
      console.error(`sendBookingReminders: No FCM token for user ${userId}`);
      continue;
    }

    const message = {
      token: userFcmToken,
      notification: {
        title: "Appointment Reminder",
        body: `You have an appointment tomorrow at ${new Date(booking.bookingDate.seconds * 1000).toLocaleString()}.`,
      },
      data: {
        type: "reminder",
        userId: userId,
        doctorId: booking.doctorId,
        bookingDate: booking.bookingDate.seconds.toString(),
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            contentAvailable: true,
          },
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);
      console.log(`sendBookingReminders: Sent reminder to user ${userId}:`, response);
    } catch (error) {
      console.error(`sendBookingReminders: Error sending reminder to user ${userId}:`, error);
    }
  }
  return null;
});