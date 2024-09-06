public with sharing class BillEmailer {
    public static void sendEmails(Map<String, Blob> emailsWithBills) {
        // Create a list to hold email messages
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        // Go through each email in the emailsWithBills map
        for (String email : emailsWithBills.keySet()) {
            // Create a new email message
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

            // Set the email address, subject, and body
            mail.setToAddresses(new List<String>{ email });
            mail.setSubject('Your Bill');
            mail.setPlainTextBody('Please find your bill attached.');

            // Attach the PDF bill to the email
            Messaging.EmailFileAttachment attach = new Messaging.EmailFileAttachment();
            attach.Body = emailsWithBills.get(email);
            attach.FileName =
                'Bill-' +
                Date.today().month() +
                '-' +
                Date.today().day() +
                '-' +
                Date.today().year() +
                '.pdf';
            attach.ContentType = 'application/pdf';
            mail.setFileAttachments(
                new List<Messaging.EmailFileAttachment>{ attach }
            );

            // Add the email message to the list
            emailsToSend.add(mail);
        }

        // Send all the emails
        Messaging.SendEmailResult[] results = Messaging.sendEmail(emailsToSend);

        // Check the results of the email send operation
        inspectResults(results);
    }

    // This method checks if the emails were sent successfully
    private static Boolean inspectResults(Messaging.SendEmailResult[] results) {
        Boolean sendResult = true;

        // Look at each result to see if the email was sent successfully
        for (Messaging.SendEmailResult res : results) {
            if (res.isSuccess()) {
                System.debug('Email sent successfully');
            } else {
                sendResult = false;
                System.debug(
                    'The following errors occurred: ' + res.getErrors()
                );
            }
        }
        return sendResult;
    }
}