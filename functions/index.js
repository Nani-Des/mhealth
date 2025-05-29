const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
admin.initializeApp();

// Helper function to format date
function formatDate(timestamp) {
  try {
    const date = timestamp.toDate();
    return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()} ${date.getHours()}:${date.getMinutes()}`;
  } catch (error) {
    console.error('Error formatting date:', error);
    return 'Unknown Date';
  }
}

// Firestore trigger for booking creation
exports.notifyOnBookingCreate = onDocumentCreated('Bookings/{bookingId}', async (event) => {
  const doc = event.data;
  const booking = doc.data();
  const patientId = booking.patientId;
  const doctorId = booking.doctorId;
  const hospitalName = booking.hospitalName || 'Unknown Hospital';
  const date = formatDate(booking.date);

  // Get FCM tokens
  const patientDoc = await admin.firestore().collection('Users').doc(patientId).get();
  const doctorDoc = await admin.firestore().collection('Users').doc(doctorId).get();

  const patientToken = patientDoc.exists ? patientDoc.data().fcmToken : null;
  const doctorToken = doctorDoc.exists ? doctorDoc.data().fcmToken : null;

  const patientPayload = {
    notification: {
      title: 'New Booking Confirmation',
      body: `Your appointment at ${hospitalName} on ${date} is confirmed.`,
    },
    data: {
      type: 'new_booking',
      bookingId: event.params.bookingId,
    },
    token: patientToken,
  };

  const doctorPayload = {
    notification: {
      title: 'New Booking Request',
      body: `A patient booked an appointment at ${hospitalName} on ${date}.`,
    },
    data: {
      type: 'new_booking',
      bookingId: event.params.bookingId,
    },
    token: doctorToken,
  };

  // Send notifications
  const notifications = [];
  if (patientToken) notifications.push(admin.messaging().send(patientPayload));
  if (doctorToken) notifications.push(admin.messaging().send(doctorPayload));

  try {
    await Promise.all(notifications);
    console.log('Notifications sent successfully');
  } catch (error) {
    console.error('Error sending notifications:', error);
  }
});

// Firestore trigger for booking updates
exports.notifyOnBookingUpdate = onDocumentUpdated('Bookings/{bookingId}', async (event) => {
  const oldData = event.data.before.data();
  const newData = event.data.after.data();
  const patientId = newData.patientId;
  const doctorId = newData.doctorId;
  const hospitalName = newData.hospitalName || 'Unknown Hospital';
  const newStatus = newData.status;
  const date = formatDate(newData.date);

  if (oldData.status !== newStatus) {
    // Get FCM tokens
    const patientDoc = await admin.firestore().collection('Users').doc(patientId).get();
    const doctorDoc = await admin.firestore().collection('Users').doc(doctorId).get();

    const patientToken = patientDoc.exists ? patientDoc.data().fcmToken : null;
    const doctorToken = doctorDoc.exists ? doctorDoc.data().fcmToken : null;

    const patientPayload = {
      notification: {
        title: 'Booking Status Updated',
        body: `Your appointment at ${hospitalName} on ${date} is now ${newStatus}.`,
      },
      data: {
        type: 'status_update',
        bookingId: event.params.bookingId,
      },
      token: patientToken,
    };

    const doctorPayload = {
      notification: {
        title: 'Booking Status Updated',
        body: `A booking at ${hospitalName} on ${date} is now ${newStatus}.`,
      },
      data: {
        type: 'status_update',
        bookingId: event.params.bookingId,
      },
      token: doctorToken,
    };

    // Send notifications
    const notifications = [];
    if (patientToken) notifications.push(admin.messaging().send(patientPayload));
    if (doctorToken) notifications.push(admin.messaging().send(doctorPayload));

    try {
      await Promise.all(notifications);
      console.log('Notifications sent successfully');
    } catch (error) {
      console.error('Error sending notifications:', error);
    }
  }
});

// Firestore trigger for booking deletions
exports.notifyOnBookingDelete = onDocumentDeleted('Bookings/{bookingId}', async (event) => {
  const booking = event.data.data();
  const patientId = booking.patientId;
  const doctorId = booking.doctorId;
  const hospitalName = booking.hospitalName || 'Unknown Hospital';
  const date = formatDate(booking.date);

  // Get FCM tokens
  const patientDoc = await admin.firestore().collection('Users').doc(patientId).get();
  const doctorDoc = await admin.firestore().collection('Users').doc(doctorId).get();

  const patientToken = patientDoc.exists ? patientDoc.data().fcmToken : null;
  const doctorToken = doctorDoc.exists ? doctorDoc.data().fcmToken : null;

  const patientPayload = {
    notification: {
      title: 'Booking Cancelled',
      body: `Your appointment at ${hospitalName} on ${date} has been cancelled.`,
    },
    data: {
      type: 'cancelled',
      bookingId: event.params.bookingId,
    },
    token: patientToken,
  };

  const doctorPayload = {
    notification: {
      title: 'Booking Cancelled',
      body: `A booking at ${hospitalName} on ${date} has been cancelled.`,
    },
    data: {
      type: 'cancelled',
      bookingId: event.params.bookingId,
    },
    token: doctorToken,
  };

  // Send notifications
  const notifications = [];
  if (patientToken) notifications.push(admin.messaging().send(patientPayload));
  if (doctorToken) notifications.push(admin.messaging().send(doctorPayload));

  try {
    await Promise.all(notifications);
    console.log('Notifications sent successfully');
  } catch (error) {
    console.error('Error sending notifications:', error);
  }
});