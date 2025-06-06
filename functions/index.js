// index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.onBookingCreated = functions.firestore
  .document('Bookings/{userId}')
  .onWrite(async (change, context) => {
    const userId = context.params.userId;
    const newData = change.after.data();
    const oldData = change.before.data();

    const newBookings = newData?.Bookings || [];
    const oldBookings = oldData?.Bookings || [];
    const addedOrUpdatedBookings = newBookings.filter((newBooking) => {
      const oldBooking = oldBookings.find(
        (b) => b.date.seconds === newBooking.date.seconds
      );
      return !oldBooking || oldBooking.status !== newBooking.status;
    });

    for (const booking of addedOrUpdatedBookings) {
      const doctorId = booking.doctorId;
      const patientId = userId;
      const status = booking.status;

      let recipientId, notificationType;
      if (status === 'Pending') {
        recipientId = doctorId;
        notificationType = 'new_booking';
      } else if (status === 'Active') {
        recipientId = patientId;
        notificationType = 'status_update';
      } else if (status === 'Terminated') {
        recipientId = patientId;
        notificationType = 'cancelled';
      } else {
        continue;
      }

      const userDoc = await admin.firestore()
        .collection('Users')
        .doc(recipientId)
        .get();
      const fcmToken = userDoc.data()?.fcmToken;
      if (!fcmToken) continue;

      const message = {
        token: fcmToken,
        notification: {
          title: status === 'Pending' ? 'New Booking Request' :
                 status === 'Active' ? 'Booking Accepted' : 'Booking Cancelled',
          body: status === 'Pending'
            ? `New booking request from patient on ${new Date(booking.date.seconds * 1000).toLocaleString()}`
            : status === 'Active'
            ? `Your booking on ${new Date(booking.date.seconds * 1000).toLocaleString()} has been accepted`
            : `Your booking on ${new Date(booking.date.seconds * 1000).toLocaleString()} has been cancelled`,
        },
        data: {
          type: notificationType,
          bookingDate: booking.date.seconds.toString(),
          userId: patientId,
          doctorId: doctorId,
        },
      };

      await admin.messaging().send(message);
    }
  });

exports.sendBookingReminders = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const now = new Date();
    const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    const bookingsSnapshot = await admin.firestore().collectionGroup('Bookings').get();
    for (const doc of bookingsSnapshot.docs) {
      const bookings = doc.data().Bookings || [];
      for (const booking of bookings) {
        const bookingDate = new Date(booking.date.seconds * 1000);
        if (
          booking.status === 'Active' &&
          bookingDate.getDate() === tomorrow.getDate() &&
          bookingDate.getMonth() === tomorrow.getMonth() &&
          bookingDate.getFullYear() === tomorrow.getFullYear()
        ) {
          const userDoc = await admin.firestore()
            .collection('Users')
            .doc(doc.id)
            .get();
          const fcmToken = userDoc.data()?.fcmToken;
          if (fcmToken) {
            await admin.messaging().send({
              token: fcmToken,
              notification: {
                title: 'Appointment Reminder',
                body: `Your appointment is scheduled for ${bookingDate.toLocaleString()}`,
              },
              data: {
                type: 'reminder',
                bookingDate: booking.date.seconds.toString(),
                doctorId: booking.doctorId,
              },
            });
          }
        }
      }
    }
  });