/* 50 most active clients */
CREATE VIEW clients_with_most_bookings AS
     SELECT TOP 50 cdb.user_id,
            SUM (cdb.full_price_ticket_count +
                  cdb.reduced_priced_ticket_count +
                  wb.reduced_priced_ticket_count +
                  wb.full_price_ticket_count) AS 'Ticket count'
       FROM conference_day_booking cdb
 INNER JOIN workshop_booking wb
         ON cdb.id = wb.conference_day_booking_id
      WHERE wb.cancel_date IS NULL
        AND cdb.cancel_date IS NULL
   GROUP BY cdb.user_id
   ORDER BY [ticket count] DESC
GO

/* Info about all business clients */
CREATE VIEW company_full_list AS
     SELECT u.id AS 'ID',
            u.login AS 'Login',
            u.email AS 'Email',
            c.name AS 'Company name',
            c.phone AS 'Company phone'
       FROM [user] u
 INNER JOIN company c
         ON u.id = c.user_id
GO

/* Clients who cancelled reservation for conference */
CREATE VIEW get_cancelled_conference_bookings AS
     SELECT cdb.cancel_date AS 'Cancel date',
            cdb.conference_day_id AS 'Conference day ID',
            u.login AS 'Client login',
            u.email AS 'Client email'
       FROM conference_day_booking cdb
 INNER JOIN [user] u
         ON cdb.user_id = u.id
      WHERE [cancel_date] IS NOT NULL
GO

/* Clients who cancelled reservation for workshop */
CREATE VIEW get_cancelled_workshop_bookings AS
     SELECT wb.cancel_date AS 'Cancel date',
            wb.workshop_id AS 'Workshop ID',
            u.login AS 'Client login',
            u.email AS 'Client email'
       FROM workshop_booking wb
 INNER JOIN conference_day_booking cdb
         ON wb.conference_day_booking_id = cdb.id
 INNER JOIN [user] u
         ON cdb.user_id = u.id
      WHERE wb.cancel_date IS NOT NULL
GO

/* Clients who didn't pay for workshop which takes place in 14 days */
CREATE VIEW get_clients_who_have_to_pay AS
     SELECT (dbo.get_conference_day_booking_ticket_price(cdb.id) *
             cdb.full_price_ticket_count +
             dbo.get_conference_day_booking_ticket_price(cdb.id) *
             cdb.reduced_priced_ticket_count *
             (dbo.get_student_discount(cdb.id) / 100 )) +
            (dbo.get_workshop_price_by_id(wb.id) *
             wb.full_price_ticket_count +
             dbo.get_workshop_price_by_id(wb.id) *
             wb.reduced_priced_ticket_count *
             (dbo.get_student_discount(cdb.id) / 100 )) AS 'to pay',
            p.amount AS 'paid',
            u.email,
            u.login,
            cd.date AS 'booking date'
       FROM conference_day_booking cdb
 INNER JOIN workshop_booking wb
         ON cdb.id = wb.conference_day_booking_id
 INNER JOIN payment p
         ON cdb.id = p.conference_day_booking_id
 INNER JOIN [user] u
         ON cdb.user_id = u.id
 INNER JOIN conference_day cd
         ON cdb.conference_day_id = cd.id
      WHERE (dbo.get_conference_day_booking_ticket_price(cdb.id) *
             cdb.full_price_ticket_count +
             dbo.get_conference_day_booking_ticket_price(cdb.id) *
             cdb.reduced_priced_ticket_count *
             (dbo.get_student_discount(cdb.id) / 100 )) +
            (dbo.get_workshop_price_by_id(wb.id) *
             wb.full_price_ticket_count +
             dbo.get_workshop_price_by_id(wb.id) *
             wb.reduced_priced_ticket_count *
             (dbo.get_student_discount(cdb.id) / 100 )) > p.amount
        AND dateadd(day, 14, cd.date) >= getdate()
GO

/* Places left on conferences */
CREATE VIEW get_conference_limit_assessment AS
     SELECT cd.id AS 'Conference ID',
            cd.max_participants AS 'Participants limit',
            SUM (cdb.full_price_ticket_count +
                 cdb.reduced_priced_ticket_count) AS 'Booked places',
                cd.max_participants -
            SUM (cdb.full_price_ticket_count +
                 cdb.reduced_priced_ticket_count) AS 'Places left'
       FROM conference_day cd
 INNER JOIN conference_day_booking cdb
         ON cd.id = cdb.conference_day_id
      WHERE cancel_date IS NULL
   GROUP BY cd.max_participants,
            cd.id
GO

/* Places left on workshops */
CREATE VIEW get_workshop_limit_assessment AS
     SELECT w.id AS 'Workshop ID',
            w.max_participants AS 'Participants limit',
            SUM (wb.reduced_priced_ticket_count +
                 wb.full_price_ticket_count) AS 'Booked places',
                w.max_participants -
            SUM (wb.reduced_priced_ticket_count +
                 wb.full_price_ticket_count) AS 'Places left'
       FROM workshop w
 INNER JOIN workshop_booking wb
         ON w.id = wb.workshop_id
      WHERE cancel_date IS NULL
   GROUP BY w.id, w.max_participants
GO

/* Clients who didn't send conference participants info */
CREATE VIEW missing_conference_participants_data AS
     SELECT u.id AS 'Client ID',
            u.login AS 'Client login',
            u.email AS 'Client email',
            cdb.id AS 'Conference day booking ID',
            cdb.full_price_ticket_count AS 'Normal price tickets',
            cdb.reduced_priced_ticket_count AS 'Reduced price tickets',
            (cdb.full_price_ticket_count +
             cdb.reduced_priced_ticket_count) AS 'Booking count',
            count (*) AS 'Reported count',
            cdb.booking_date AS 'Booking date',
            cd.date AS 'Date'
       FROM [user] u
 INNER JOIN conference_day_booking cdb
         ON u.id = cdb.user_id
        AND cdb.cancel_date IS NULL
 INNER JOIN conference_day_registration cdr
         ON cdb.id = cdr.conference_day_booking_id
        AND cdr.cancel_date IS NULL
 INNER JOIN conference_day cd
         ON cd.id = cdb.conference_day_id
   GROUP BY u.id,
            u.login,
            u.email,
            cdb.id,
            cdb.full_price_ticket_count,
            cdb.reduced_priced_ticket_count,
            (cdb.full_price_ticket_count +
             cdb.reduced_priced_ticket_count),
            cdb.booking_date,
            cd.date
     HAVING (cdb.full_price_ticket_count + cdb.reduced_priced_ticket_count) > count (*)
        AND cd.date < dateadd(day, 7, getdate())
GO

/* Clients who didn't send workshop participants info */
CREATE VIEW missing_conference_workshops_data AS
     SELECT u.id AS 'Client ID',
            u.login AS 'Client login',
            u.email AS 'Client email',
            cdb.id AS 'Conference day booking ID',
            wb.id AS 'Workshop booking ID',
            wb.full_price_ticket_count AS 'Normal ticket count',
            wb.reduced_priced_ticket_count AS 'Reduced ticket count',
            (wb.full_price_ticket_count +
             wb.reduced_priced_ticket_count) AS 'Ticket count',
            count (*) AS 'Reported count',
            wb.booking_date AS 'Workshop booking date',
            cd.date AS 'Conference day date'
       FROM [user] u
 INNER JOIN conference_day_booking cdb
         ON u.id = cdb.user_id
        AND cdb.cancel_date IS NULL
 INNER JOIN workshop_booking wb
         ON cdb.id = wb.conference_day_booking_id
        AND wb.cancel_date IS NULL
 INNER JOIN workshop_registration wr
         ON wb.id = wr.workshop_booking_id
        AND wr.cancel_date IS NULL
 INNER JOIN conference_day cd
         ON cdb.conference_day_id = cd.id
   GROUP BY u.id,
            u.login,
            u.email,
            cdb.id,
            wb.id,
            wb.full_price_ticket_count,
            wb.reduced_priced_ticket_count,
            (wb.full_price_ticket_count +
             wb.reduced_priced_ticket_count),
            wb.booking_date,
            cd.date
     HAVING (wb.full_price_ticket_count +
             wb.reduced_priced_ticket_count) > count (*)
        AND cd.date < dateadd(day, 7, wb.booking_date)
GO

/* 50 most popular conferences */
CREATE VIEW most_popular_conferences AS
     SELECT TOP 50 c.name AS 'Conference name',
            c.date_start AS 'Conference start',
            SUM (cdb.full_price_ticket_count +
                 cdb.reduced_priced_ticket_count) AS 'Booking count'
       FROM conference c
 INNER JOIN conference_day cd
         ON c.id = cd.conference_id
 INNER JOIN conference_day_booking cdb
         ON cd.id = cdb.conference_day_id
        AND cdb.cancel_date IS NULL
   GROUP BY c.id,
            c.name,
            c.date_start
   ORDER BY [Booking count] DESC
GO

/* 50 most popular workshops */
CREATE VIEW most_popular_workshops AS
    SELECT TOP 50 c.name AS 'Conference name',
           w.name AS 'Workshop name',
           c.date_start AS 'Conference start',
           SUM (wb.full_price_ticket_count +
                wb.reduced_priced_ticket_count) AS 'Booking count'
      FROM conference c
INNER JOIN conference_day cd
        ON c.id = cd.conference_id
INNER JOIN workshop w
        ON cd.id = w.conference_day_id
INNER JOIN workshop_booking wb
        ON w.id = wb.workshop_id AND wb.cancel_date IS NULL
  GROUP BY c.name,
           w.name,
           c.date_start
  ORDER BY [Booking count] DESC
GO


