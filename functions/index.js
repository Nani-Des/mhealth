const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.onBookingCreated = functions.firestore
  .document("Bookings/{userId}")
  .onCreate(async (snap, context) => {
    console.log("onBookingCreated: Started execution for userId: ", context.params.userId);
    const data = snap.data();
    const userId = context.params.userId;
    const bookings = data.Bookings || [];
    if (bookings.length === 0) {
      console.log("onBookingCreated: No bookings found in document");
      return null;
    }

    const newBooking = bookings[bookings.length - 1]; // Assume last booking is the new one
    const doctorId = newBooking.doctorId;

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

    const userName = `${userDoc.data().Fname || "User"} ${userDoc.data().Lname || ""}`.trim();
    const doctorFcmToken = doctorDoc.data().fcmToken;

    if (!doctorFcmToken) {
      console.error(`onBookingCreated: No FCM token for doctor ${doctorId}`);
      return null;
    }

    const doctorMessage = {
      token: doctorFcmToken,
      notification: {
        title: "New Booking Request",
        body: `You have a new booking request from ${userName} for ${new Date(newBooking.date.seconds * 1000).toLocaleString()}.`,
      },
      data: {
        type: "new_booking",
        userId: userId,
        doctorId: doctorId,
        bookingDate: newBooking.date.seconds.toString(),
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
      const response = await admin.messaging().send(doctorMessage);
      console.log(`onBookingCreated: Sent new_booking notification to doctor ${doctorId}:`, response);
    } catch (error) {
      console.error(`onBookingCreated: Error sending notification to doctor ${doctorId}:`, error);
    }

    // Optional: Notify patient (if required)
    const userFcmToken = userDoc.data().fcmToken;
    if (userFcmToken) {
      const userMessage = {
        token: userFcmToken,
        notification: {
          title: "Booking Created",
          body: `Your booking with doctor for ${new Date(newBooking.date.seconds * 1000).toLocaleString()} has been created.`,
        },
        data: {
          type: "new_booking",
          userId: userId,
          doctorId: doctorId,
          bookingDate: newBooking.date.seconds.toString(),
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
        const response = await admin.messaging().send(userMessage);
        console.log(`onBookingCreated: Sent new_booking notification to user ${userId}:`, response);
      } catch (error) {
        console.error(`onBookingCreated: Error sending notification to user ${userId}:`, error);
      }
    }

    return null;
  });

exports.onBookingStatusUpdated = functions.firestore
  .document("Bookings/{userId}")
  .onUpdate(async (change, context) => {
    console.log("onBookingStatusUpdated: Started execution for userId: ", context.params.userId);
    const newData = change.after.data();
    const previousData = change.before.data();
    const userId = context.params.userId;

    const newBookings = newData.Bookings || [];
    const previousBookings = previousData.Bookings || [];

    for (let i = 0; i < newBookings.length; i++) {
      const newBooking = newBookings[i];
      const previousBooking = previousBookings[i] || {};

      if (newBooking.status !== previousBooking.status) {
        console.log(`onBookingStatusUpdated: Status changed for booking index ${i}, new status: ${newBooking.status}`);
        let userDoc, doctorDoc;
        try {
          userDoc = await admin.firestore().collection("Users").doc(userId).get();
          doctorDoc = await admin.firestore().collection("Users").doc(newBooking.doctorId).get();
        } catch (error) {
          console.error(`onBookingStatusUpdated: Error fetching user/doctor docs - userId: ${userId}, doctorId: ${newBooking.doctorId}, error:`, error);
          return null;
        }

        if (!userDoc.exists) {
          console.error(`onBookingStatusUpdated: User not found: ${userId}`);
          return null;
        }
        if (!doctorDoc.exists) {
          console.error(`onBookingStatusUpdated: Doctor not found: ${newBooking.doctorId}`);
          return null;
        }

        const userFcmToken = userDoc.data().fcmToken;
        if (!userFcmToken) {
          console.error(`onBookingStatusUpdated: No FCM token for user ${userId}`);
          return null;
        }

        let title, body, type;
        if (newBooking.status === "Active" && previousBooking.status === "Pending") {
          title = "Booking Accepted";
          body = `Your booking with doctor for ${new Date(newBooking.date.seconds * 1000).toLocaleString()} has been accepted.`;
          type = "booking_accepted";
        } else if (newBooking.status === "Cancelled") {
          title = "Booking Terminated";
          body = `Your booking with doctor for ${new Date(newBooking.date.seconds * 1000).toLocaleString()} was terminated.`;
          type = "booking_cancelled";
        } else {
          console.log(`onBookingStatusUpdated: No notification needed for status: ${newBooking.status}`);
          continue;
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
            doctorId: newBooking.doctorId,
            bookingDate: newBooking.date.seconds.toString(),
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
        } catch (error) {
          console.error(`onBookingStatusUpdated: Error sending ${type} notification to user ${userId}:`, error);
        }
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
    bookingsSnapshot = await admin.firestore().collection("Bookings").get();
  } catch (error) {
    console.error("sendBookingReminders: Error fetching bookings:", error);
    return null;
  }

  for (const doc of bookingsSnapshot.docs) {
    const userId = doc.id;
    const bookings = doc.data().Bookings || [];
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

    for (const booking of bookings) {
      const bookingDate = new Date(booking.date.seconds * 1000);
      if (booking.status === "Active" && bookingDate >= tomorrow && bookingDate <= tomorrowEnd) {
        const message = {
          token: userFcmToken,
          notification: {
            title: "Appointment Reminder",
            body: `You have an appointment tomorrow at ${bookingDate.toLocaleString()} with your doctor.`,
          },
          data: {
            type: "reminder",
            userId: userId,
            doctorId: booking.doctorId,
            bookingDate: booking.date.seconds.toString(),
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
    }
  }
  return null;
});