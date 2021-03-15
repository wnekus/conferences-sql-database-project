/* Checks if there is enough free slots on conference day to make booking */
CREATE TRIGGER not_enough_conference_places ON conference_day_booking
AFTER INSERT AS
    IF EXISTS SELECT *
                FROM inserted i
               WHERE dbo.get_conference_day_free_places(i.conference_day_id ) < 0)
        BEGIN
            THROW 50002 , 'Not enough places to book conference day' , 1
        END
GO

/* Checks if there is enough free slots on workshop to make booking */
CREATE TRIGGER not_enough_workshop_places ON workshop_booking
AFTER INSERT AS
    IF EXISTS SELECT *
                FROM inserted i
               WHERE dbo.get_workshop_free_places(i. workshop_id ) < 0)
        BEGIN
            THROW 50002 , 'Not enough places to book workshop' , 1
        END
GO

/* Checks if new number of slots for conference is correct */
CREATE TRIGGER less_places_then_bookings ON conference_day
AFTER UPDATE AS
    IF EXISTS  SELECT *
                 FROM inserted AS i
            LEFT JOIN conference_day_booking AS bd
                   ON bd.conference_day_id = i.id
                WHERE cancel_date IS NULL
             GROUP BY i.id,
                      i.max_participants
               HAVING i.max_participants < sum(bd.full_price_ticket_count) +
                  SUM (bd.reduced_priced_ticket_count)
        BEGIN
            THROW 50001, 'Cannot change places limit - too many booked places', 1
        END
GO

/* Checks if new number of slots for workshop is correct */
CREATE TRIGGER less_places_then_workshop_bookings ON workshop
AFTER UPDATE AS
    IF EXISTS SELECT *
                FROM inserted AS i
           LEFT JOIN workshop_booking AS wd
                  ON wd.workshop_id = i.id
               WHERE cancel_date IS NULL
            GROUP BY i.id,
                     i.max_participants
              HAVING i.max_participants < sum(wd. full_price_ticket_count ) +
                 SUM (wd.reduced_priced_ticket_count)
        BEGIN
            THROW 50001, 'Cannot change places limit for workshop - too many booked places', 1
        END
GO

/* Checks if number of given participants for conference day is not bigger than number of reserved tickets */
CREATE TRIGGER not_enough_places_conference_booking ON conference_day_registration
AFTER INSERT AS
    IF EXISTS SELECT i.id,
                     COUNT(cdr.conference_day_booking_id)
                FROM inserted i
          INNER JOIN conference_day_booking cdb
                  ON i.conference_day_booking_id = cdb.id
          INNER JOIN conference_day_registration cdr
                  ON cdb.id = cdr.conference_day_booking_id
               WHERE cdr.cancel_date IS NULL
            GROUP BY i.id,
                     cdr.conference_day_booking_id,
                     cdb.full_price_ticket_count,
                     cdb.reduced_priced_ticket_count
              HAVING (COUNT(cdr.conference_day_booking_id) -
                      cdb.full_price_ticket_count -
                      cdb.reduced_priced_ticket_count) > 0
        BEGIN
            THROW 50002, 'Not enough tickets booked', 1
        END
GO

/* Checks if number of given participants for workshop is not bigger than number of reserved tickets */
CREATE TRIGGER not_enough_places_workshop_booking ON workshop_registration
AFTER INSERT AS
    IF EXISTS SELECT i.id,
                     COUNT(wr. workshop_booking_id )
                FROM inserted i
          INNER JOIN workshop_booking wb
                  ON i.workshop_booking_id = wb.id
          INNER JOIN workshop_registration wr
                  ON wb.id = wr.workshop_booking_id
               WHERE wr.cancel_date IS NULL
            GROUP BY i.id,
                     wr.workshop_booking_id,
                     wb.full_price_ticket_count,
                     wb.reduced_priced_ticket_count
              HAVING (COUNT(wr.workshop_booking_id) -
                      wb.full_price_ticket_count -
                      wb.reduced_priced_ticket_count) > 0
        BEGIN
            THROW 50002, 'Not enough tickets booked', 1
        END
GO

/* Checks if there is enough free slots for conference day to change number of tickets */
CREATE TRIGGER too_many_tickets ON conference_day_booking
AFTER UPDATE AS
    IF EXISTS SELECT *
                FROM inserted AS i
          INNER JOIN deleted as d
                  ON i.id = d .id
            GROUP BY i.id,
                     d.full_price_ticket_count,
                     d.reduced_priced_ticket_count,
                     i.full_price_ticket_count,
                     i.reduced_priced_ticket_count,
                     d.conference_day_id
              HAVING ((dbo.get_conference_day_free_places(d.conference_day_id) +
                       d.full_price_ticket_count +
                       d.reduced_priced_ticket_count -
                       i.reduced_priced_ticket_count -
                       i.full_price_ticket_count) < -1)
        BEGIN
            THROW 50002, 'Cannot change places list - too many booked places', 1
        END
GO

/* Checks if there is enough free slots for workshop to change number of tickets */
CREATE TRIGGER too_many_workshop_tickets ON workshop_booking
AFTER UPDATE AS
    IF EXISTS SELECT *
                FROM inserted AS i
          INNER JOIN deleted as d
                  ON i.id = d.id
            GROUP BY i.id,
                     d.full_price_ticket_count,
                     d.reduced_priced_ticket_count,
                     i.full_price_ticket_count,
                     i.reduced_priced_ticket_count,
                     d.workshop_id
              HAVING ((dbo.get_workshop_free_places(d.workshop_id ) +
                       d.full_price_ticket_count +
                       d.reduced_priced_ticket_count -
                       i.reduced_priced_ticket_count -
                       i.full_price_ticket_count) < -1)
        BEGIN
            THROW 50002, 'Cannot change places list - too many booked places', 1
        END
GO

/* Checks if number of reserved tickets for workshop is not bigger than number of tickest for conference day */
CREATE TRIGGER more_workshop_tickets_then_conference ON workshop_booking
AFTER INSERT, UPDATE AS
    IF EXISTS SELECT *
                FROM inserted AS i
          INNER JOIN conference_day_booking cdb
                  ON cdb.id = i.conference_day_booking_id
               WHERE cdb.reduced_priced_ticket_count +
                     cdb.full_price_ticket_count -
                     i.reduced_priced_ticket_count -
                     i.full_price_ticket_count < 0
        BEGIN
            THROW 50002, 'Less tickets for conference then for workshop', 1
        END
GO

/* Cancel registration for conference day after cancel of booking */
CREATE TRIGGER cancel_day_reservations_after_cancelling_day_booking ON conference_day_booking
AFTER UPDATE AS
    BEGIN
        UPDATE conference_day_registration
           SET cancel_date = getdate()
         WHERE conference_day_booking_id
            IN (SELECT i. id
                  FROM inserted AS i
                  JOIN deleted AS d
                    ON i.id = d.id
                 WHERE i.cancel_date IS NOT NULL
                   AND d.cancel_date IS NULL)
    END
GO

/* Cancel registration for workshop after cancel of booking for conference */
CREATE TRIGGER cancel_workshop_booking_after_cancelling_conference_day_booking ON conference_day_booking
AFTER UPDATE AS
    BEGIN
        UPDATE workshop_booking
           SET cancel_date = getdate()
         WHERE conference_day_booking_id
            IN (SELECT i.id
                  FROM inserted AS i
                  JOIN deleted AS d
                    ON i.id = d.id
                 WHERE i.cancel_date IS NOT NULL
                   AND d.cancel_date IS NULL)
    END
GO

/* Cancel registration for workshop after cancel of booking for conference day */
CREATE TRIGGER cancel_workshop_registration_after_cancelling_conference_registration ON conference_day_registration
AFTER UPDATE AS
    BEGIN
        UPDATE workshop_registration
           SET cancel_date = getdate()
         WHERE conference_day_registration_id
            IN (SELECT i.id
                  FROM inserted AS i
                  JOIN deleted AS d
                    ON i.id = d.id
                 WHERE i.cancel_date IS NOT NULL
                   AND d.cancel_date IS NULL)
    END
GO

/* Cancel registration for workshop after cancel of booking for this workshop */
CREATE TRIGGER cancel_workshop_reservations_after_cancelling_workshop_booking ON workshop_booking
AFTER UPDATE AS
    BEGIN
    UPDATE workshop_registration
       SET cancel_date = getdate()
     WHERE workshop_booking_id
        IN (SELECT i.id
              FROM inserted AS i
              JOIN deleted AS d
                ON i.id = d.id
             WHERE i.cancel_date IS NOT NULL
               AND d.cancel_date IS NULL)
    END
GO

/* Checks data inserted to company table */
CREATE TRIGGER check_data_for_company ON company
AFTER INSERT, UPDATE AS
    BEGIN
        SET NOCOUNT ON
        IF EXISTS SELECT *
                    FROM inserted
              CROSS JOIN company
                   WHERE inserted.id != company.id
                     AND inserted.name = company.name
            BEGIN
                THROW 70033, 'There is already company under such name in thedatabase', 1
            END
        IF EXISTS SELECT *
                    FROM inserted
              CROSS JOIN company
                   WHERE inserted.id != company.id
                     AND inserted.phone = company.phone
            BEGIN
                THROW 70033, 'There is already company with such name in the database', 1
            END
    END
GO

/* Checks if conference date is correct */
CREATE TRIGGER check_conference_day_date ON conference_day
AFTER INSERT, UPDATE AS
    BEGIN
        SET NOCOUNT ON
        IF EXISTS SELECT *
                    FROM inserted
              CROSS JOIN conference_day
                   WHERE inserted.id != conference_day.id
                     AND inserted.date = conference_day.date
                     AND inserted.conference_id = conference_day.conference_id
            BEGIN
                THROW 70034, 'There is already conference day with the same date', 1
            END
    END
GO

/* Checks if payment is done until 7 days after booking */
CREATE TRIGGER check_payment_date ON payment
AFTER INSERT, UPDATE AS
    BEGIN
        IF EXISTS SELECT p.payment_date
                    FROM payment p
               LEFT JOIN conference_day_booking cdb
                      ON p.conference_day_booking_id = cdb.id
               LEFT JOIN conference_day_registration cdr
                      ON cdb.id = cdr.conference_day_booking_id
                   WHERE p.payment_date > dateadd(day, 7, cdr.registration_date)
            BEGIN
                THROW 70026, 'Conference has to be paid in 7 days since registration', 1
            END
    END
GO

/* Checks data inserted to price_level table */
CREATE TRIGGER check_data_for_price_level ON price_level
AFTER INSERT AS
    BEGIN
        SET NOCOUNT ON
            IF NOT EXISTS SELECT *
                            FROM inserted i
                      CROSS JOIN conference_day cd
                           WHERE i.conference_day_id = cd.id
                BEGIN
                    THROW 70043, 'There is no such conference in the database', 1
                END
            IF EXISTS SELECT *
                        FROM inserted i
                  CROSS JOIN price_level pl
                       WHERE i.date_limit = pl.date_limit
                         AND i.id != pl.id
                         AND i.conference_day_id = pl.conference_day_id
                BEGIN
                    THROW 70044, 'Duplicate end date for the price level', 1
                END
    END
GO

/* Checks inserted data for client */
CREATE TRIGGER check_data_for_client ON [user]
AFTER INSERT, UPDATE AS
    BEGIN
        SET NOCOUNT ON
            IF EXISTS SELECT *
                        FROM inserted
                  CROSS JOIN [user]
                       WHERE inserted.id != dbo.[user].id
                         AND inserted.email = dbo.[user].email
                BEGIN
                    THROW 70031, 'There is already such email in the database', 1
                END
            IF EXISTS SELECT *
                        FROM inserted
                  CROSS JOIN [user]
                       WHERE inserted.id != dbo.[user].id
                         AND inserted.login = dbo.[user].login
                BEGIN
                    THROW 70032 , 'There is already such login in the database' , 1
                END
    END
GO

/* Checks data inserted in workshop */
CREATE TRIGGER check_data_for_workshop ON workshop
AFTER INSERT, UPDATE AS
    BEGIN
        SET NOCOUNT ON
            IF NOT EXISTS SELECT *
                            FROM inserted i
                      CROSS JOIN conference_day cd
                           WHERE i.conference_day_id = cd.id
                BEGIN
                    THROW 70045 , 'There is no such conference day' , 1
                END
    END
GO