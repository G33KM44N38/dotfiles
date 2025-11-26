// Test file for multi-line console statements

function testMultiline() {
	console.log(
		'🎉 [TRPC Appointment.make] Procedure completed successfully:',
		{
			appointmentId: (newAppointment ?? appointment)._id,
			status: (newAppointment ?? appointment).status,
			timestamp: new Date().toISOString(),
		}
	);

	const result = calculateSomething();

	console.warn(
		'This is a warning',
		'with multiple',
		'arguments'
	);

	return result;
}

function another() {
	console.error(
		'An error occurred at',
		new Date().toISOString()
	);
}
