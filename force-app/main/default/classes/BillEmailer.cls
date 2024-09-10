
public with sharing class BillEmailer {
  private static final Integer MAX_EMAILS_PER_DAY = 5000; // Adjust this based on your org's limit
  private static Integer emailsSentToday = 0;

  public static void sendEmails(Map<String, Blob> emailsWithBills) {
    List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

    for (String email : emailsWithBills.keySet()) {
      if (emailsSentToday >= MAX_EMAILS_PER_DAY) {
        throw new BillEmailException(
          'Daily email limit reached. Stopping further processing.'
        );
      }

      Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
      mail.setToAddresses(new List<String>{ email });
      mail.setSubject('Your Bill');
      mail.setPlainTextBody('Please find your bill attached.');

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

      emailsToSend.add(mail);
      emailsSentToday++;
    }

    if (!emailsToSend.isEmpty()) {
      try {
        Messaging.SendEmailResult[] results = Messaging.sendEmail(emailsToSend);
        inspectResults(results);
      } catch (System.EmailException e) {
        throw new BillEmailException('Email limit exceeded: ' + e.getMessage());
      }
    }
  }

  private static void inspectResults(Messaging.SendEmailResult[] results) {
    List<String> errors = new List<String>();

    for (Messaging.SendEmailResult res : results) {
      if (res.isSuccess()) {
        System.debug('Email sent successfully');
      } else {
        for (Messaging.SendEmailError err : res.getErrors()) {
          String errorMessage =
            'Error sending email: ' +
            err.getMessage() +
            ' (Status Code: ' +
            err.getStatusCode() +
            ')';
          System.debug(errorMessage);
          errors.add(errorMessage);

          if (
            err.getStatusCode() == System.StatusCode.SINGLE_EMAIL_LIMIT_EXCEEDED
          ) {
            throw new BillEmailException(
              'Email limit exceeded. Stopping further processing.'
            );
          }
        }
      }
    }

    if (!errors.isEmpty()) {
      throw new BillEmailException(String.join(errors, '\n'));
    }
  }

  public class BillEmailException extends Exception {
  }
}
