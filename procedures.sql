/* Add client to db */
CREATE PROCEDURE [add_client]
    @login varchar(255),
    @password varchar(255),
    @email varchar(255),
    @is_active bit
AS
    BEGIN TRY
        INSERT INTO [user](login, password, email, is_active)
        VALUES (@login, @password, @email, @is_active)
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when adding client: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO

/* Add company to db which client can be representative */
CREATE PROCEDURE [add_company]
    @name varchar(255),
    @phone varchar(20),
    @user_id int
AS
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM [user] WHERE id = @user_id)
            BEGIN
                THROW 52000, 'Client with this Id doesn''t exists', 1
            END
        INSERT INTO company(name, phone, user_id)
        VALUES (@name, @phone, @user_id)
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when adding client: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO

/* Add individual client */
CREATE PROCEDURE [add_individual_client]
    @name varchar(255),
    @surname varchar(255),
    @user_id int
AS
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM [user] WHERE id = @user_id)
            BEGIN
                THROW 52000, 'Client with this Id doesn''t exists', 1
            END
        INSERT INTO individual_user (name, surname, user_id)
        VALUES (@name, @surname, @user_id)
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when adding individual client: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1
    END CATCH
GO

/* Add conference */
CREATE PROCEDURE [add_conference]
    @name varchar(256),
    @description text,
    @date_start date,
    @date_end date
AS
    BEGIN TRY
        IF (@date_start >= @date_end)
            BEGIN
                THROW 52000, 'Start date can not be later than end date', 1
            END
        INSERT INTO conference (name, description, date_start, date_end)
        VALUES (@name, @description, @date_start, @date_end)
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when adding conference: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO

/* Add conference day */
CREATE PROCEDURE [add_conference_day]
    @theme nvarchar(256),
    @lecturer ncarchar(256),
    @date date,
    @time_start time,
    @time_end time,
    @max_participants int,
    @conference_id int,
    @student_discount int
AS
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM conference WHERE id = @conference_id)
            BEGIN
                THROW 52000, 'Conference with this Id doesn''t exists', 1
            END
        IF NOT EXISTS (SELECT * FROM conference WHERE id = @conference_id
                                                  AND conference. date_start <=@date
                                                  AND conference. date_end >=@date)
            BEGIN
                THROW 52000, 'Conference day date is incorrect', 1
            END
        IF (@time_start >= @time_end)
            BEGIN
                THROW 52000, 'Start time can not be later than end time', 1
            END
        IF (@max_participants< 0 )
            BEGIN
                THROW 52000, 'Participants limit can not be negative', 1
            END
        INSERT INTO conference_day (theme, lecturer, date, time_start, time_end, max_participants, conference_id, student_discount)
        VALUES (@theme, @lecturer, @date, @time_start, @time_end, @max_participants, @conference_id, @student_discount)
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when adding conference day: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1 ;
    END CATCH
GO

/* Add booking for conference day */
CREATE PROCEDURE [add_conference_day_booking]
    @full_price_ticket_count int,
    @reduced_priced_ticket_count int,
    @conference_day_id int,
    @user_id int
AS
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM conference_day WHERE id = @conference_day_id)
            BEGIN
                THROW 52000, 'Conference day with this Id doesn''t exists', 1
            END
        IF NOT EXISTS (SELECT * FROM [user] WHERE id = @user_id)
            BEGIN
                THROW 52000, 'User with this Id doesn''t exists', 1
            END
        IF (@full_price_ticket_count < 0 OR @reduced_priced_ticket_count < 0)
            BEGIN
                THROW 52000, 'Tickets number can not be negative', 1
            END
        DECLARE @conference_date DATE = (SELECT date FROM conference_day WHERE id = @conference_day_id)
        IF @conference_date < (DATEADD (day, 14, getdate()))
            BEGIN
                THROW 52000 , 'Cannot book conference for less than 14 days before start', 1
            END
        INSERT INTO conference_day_booking (booking_date, full_price_ticket_count, reduced_priced_ticket_count, conference_day_id, user_id)
        VALUES (getdate(), @full_price_ticket_count, @reduced_priced_ticket_count, @conference_day_id, @user_id)
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when adding conference day booking: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO

/* Add registration for conference day */
CREATE PROCEDURE [add_conference_day_registration]
    @participant_id int,
    @conference_day_booking_id int,
    @is_student bit
AS
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM conference_day_booking WHERE id = @conference_day_booking_id)
            BEGIN
                THROW 52000, 'Conference day booking with this Id doesn''t exists', 1
            END
        IF NOT EXISTS (SELECT * FROM participant WHERE id = @participant_id)
            BEGIN
                THROW 52000, 'Participant with this Id doesn''t exists', 1
            END
        IF NOT EXISTS (SELECT * FROM conference_day_booking WHERE id = @conference_day_booking_id
                                                              AND cancel_date IS NULL)
            BEGIN
                THROW 52000, 'Conference day booking is cancelled', 1
            END
        INSERT INTO conference_day_registration (registration_date, participant_id, conference_day_booking_id, is_student)
        VALUES (getdate(), @participant_id, @conference_day_booking_id, @is_student)
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when adding conference day booking: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO

/* Add workshop */
CREATE PROCEDURE [add_workshop]
    @name varchar(256),
    @max_participants int,
    @conference_day_id int,
    @price decimal (6, 2),
    @start_time datetime,
    @end_time datetime
AS
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM conference_day WHERE id = @conference_day_id)
            BEGIN
                THROW 52000, 'Conference day with this Id doesn''t exists', 1
            END
        IF (@price < 0)
            BEGIN
                THROW 52000, 'Price can not be nagative', 1
            END
        IF (@max_participants < 0)
            BEGIN
                THROW 52000, 'Participants limit can not be negative', 1
            END
        IF (@start_time >= @end_time)
            BEGIN
                THROW 52000 , 'Start time can not be later than end time' , 1
            END
        INSERT INTO workshop (name, max_participants, conference_day_id, price, start_time, end_time)
        VALUES(@name, @max_participants, @conference_day_id, @price, @start_time, @end_time)
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when adding workshop: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO

/* Add booking for workshop */
CREATE PROCEDURE [add_workshop_booking]
    @full_price_ticket_count int,
    @reduced_priced_ticket_count int,
    @conference_day_booking_id int,
    @workshop_id int
AS
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM workshop WHERE id = @workshop_id)
            BEGIN
                THROW 52000, 'Workshop with this Id doesn''t exists', 1
            END
        IF NOT EXISTS (SELECT * FROM conference_day_booking WHERE id = @conference_day_booking_id
                                                              AND cancel_date IS NULL)
            BEGIN
                THROW 52000, 'Conference day booking with this Id doesn''t exists', 1
            END
        IF (SELECT conference_day_id FROM conference_day_booking WHERE id = @conference_day_booking_id) !=
           (SELECT workshop.conference_day_id FROM workshop WHERE id = @workshop_id)
            BEGIN
                THROW 52000, 'Workshop doesn''t belong to conference day', 1
            END
        IF (@full_price_ticket_count < 0 OR @reduced_priced_ticket_count < 0 )
            BEGIN
                THROW 52000, 'Tickets number can not be negative', 1
            END
        INSERT INTO workshop_booking (booking_date, full_price_ticket_count, reduced_priced_ticket_count, conference_day_booking_id, workshop_id)
        VALUES (getdate(), @full_price_ticket_count, @reduced_priced_ticket_count,@conference_day_booking_id, @workshop_id)
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when adding workshop booking: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO

/* Add registration for workshop */
CREATE PROCEDURE [add_workshop_registration]
    @workshop_booking_id int,
    @conference_day_registration_id int
AS
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM workshop_booking WHERE id = @workshop_booking_id)
            BEGIN
                THROW 52000, 'Workshop booking with this Id doesn''t exists', 1
            END
        IF NOT EXISTS (SELECT * FROM conference_day_registration WHERE id = @conference_day_registration_id)
            BEGIN
                THROW 52000, 'Conference day registration with this Id doesn''t exists', 1
            END
        IF NOT EXISTS (SELECT * FROM workshop_booking WHERE id = @workshop_booking_id
                                                        AND cancel_date IS NULL)
            BEGIN
                THROW 52000, 'Workshop booking is cancelled', 1
            END
        DECLARE @workshop_start_time datetime =(SELECT start_time
                                                  FROM workshop
                                            INNER JOIN workshop_booking b
                                                    ON workshop.id = b.workshop_id
                                                 WHERE b. id = @workshop_booking_id);
        DECLARE @workshop_end_time datetime = (SELECT start_time
                                                 FROM workshop
                                           INNER JOIN workshop_booking b
                                                   ON workshop.id = b.workshop_id
                                                WHERE b.id = @workshop_booking_id);
        DECLARE @participant int = (SELECT participant_id FROM conference_day_registration WHERE id = @conference_day_registration_id);
        IF EXISTS (SELECT *
                     FROM conference_day_registration
               INNER JOIN workshop_registration wr
                       ON conference_day_registration.id = wr.conference_day_registration_id
               INNER JOIN workshop_booking wb
                       ON wr.workshop_booking_id = wb.id
               INNER JOIN workshop w
                       ON wb.workshop_id = w.id
                    WHERE participant_id = @participant
                      AND ((@workshop_start_time < w.start_time
                      AND   w.start_time < @workshop_end_time)
                       OR  (w.start_time < @workshop_start_time
                      AND   @workshop_start_time < w.end_time)
                       OR  (@workshop_start_time >= w.start_time
                      AND   w.end_time >= @workshop_end_time)
                       OR  (w.start_time >= @workshop_start_time
                      AND   @workshop_end_time >= w.end_time ))
                      AND wb.cancel_date IS NOT NULL)
            BEGIN
                THROW 52000 ,'This participant has already workshop in this time', 1
            END
        INSERT INTO workshop_registration (registration_date, workshop_booking_id, conference_day_registration_id)
        VALUES (getdate(), @workshop_booking_id, @conference_day_registration_id)
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when adding workshop registration: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO

/* Add price level for conference day */
CREATE PROCEDURE [add_price_level]
    @date_limit date,
    @day_price decimal (6, 2),
    @conference_day_id int
AS
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM conference_day WHERE id = @conference_day_id)
            BEGIN
                THROW 52000, 'Conference day with this Id doesn''t exists', 1
            END
        IF (@day_price < 0)
            BEGIN
                THROW 52000, 'Price can not be negative', 1
            END
        INSERT INTO price_level (date_limit, day_price, conference_day_id)
        VALUES (@date_limit, @day_price, @conference_day_id)
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when adding price level: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO

/* Add new made payment */
CREATE PROCEDURE [add_payment]
    @payment_date datetime,
    @amount decimal (6, 2),
    @conference_day_booking_id int,
    @user_id int
AS
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM conference_day_booking WHERE id = @conference_day_booking_id)
            BEGIN
                THROW 52000, 'Conference day booking with this Id doesn''t exists', 1
            END
        IF (@amount <= 0)
            BEGIN
                THROW 52000, 'Incorrect amount', 1
            END
        INSERT INTO payment (payment_date, amount, conference_day_booking_id, user_id)
        VALUES (@payment_date, @amount, @conference_day_booking_id, @user_id)
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when adding payment: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO


/* Add conference/workshop participant */
CREATE PROCEDURE [add_participant]
    @name varchar(255),
    @surname varchar(255),
    @PESEL varchar(255)
AS
    BEGIN TRY
        IF EXISTS(SELECT * FROM participant WHERE PESEL = @PESEL)
            BEGIN
                THROW 52000, 'There is already participant with this PESEL', 1
            END
        INSERT INTO participant (name, surname, PESEL)
        VALUES (@name, @surname, @PESEL)
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when adding participant: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO

/* Cancel booking for conference day */
CREATE PROCEDURE [cancel_conference_day_booking]
    @id int
AS
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM conference_day_booking WHERE id = @id)
            BEGIN
                THROW 52000, 'Conference day booking with this Id doesn''t exists', 1
            END
        IF @id IS NOT NULL
            BEGIN
                UPDATE conference_day_booking
                   SET cancel_date = getdate()
                 WHERE id = @id
            END
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when cancelling conference day booking: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO

/* Cancel registration for conference day */
CREATE PROCEDURE [cancel_conference_day_registration]
    @id int
AS
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM conference_day_registration WHERE id = @id)
            BEGIN
                THROW 52000, 'Conference day registration with this Id doesn''t exists', 1
            END
        IF @id IS NOT NULL
            BEGIN
                UPDATE conference_day_registration
                   SET cancel_date = getdate()
                 WHERE id = @id
            END
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when cancelling conference day registration: '+ ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO

/* Cancel booking for workshop */
CREATE PROCEDURE [cancel_workshop_booking]
    @id int
AS
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM workshop_booking WHERE id = @id)
            BEGIN
                THROW 52000, 'Workshop booking with this Id doesn''t exists', 1
            END
        IF @id IS NOT NULL
            BEGIN
                UPDATE workshop_booking
                   SET cancel_date = getdate()
                 WHERE id = @id
            END
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when cancelling workshop booking: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO

/* Cancel registration for workshop */
CREATE PROCEDURE [cancel_conference_day_registration]
    @id int
AS
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM conference_day_registration WHERE id = @id)
            BEGIN
                THROW 52000, 'Conference day registration with this Id doesn''t exists', 1
            END
        IF @id IS NOT NULL
            BEGIN
                UPDATE conference_day_registration
                   SET cancel_date = getdate()
                 WHERE id = @id
            END
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when cancelling conference day registration: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO

/* Changes conferences day details */
CREATE PROCEDURE [change_conference_day_details]
    @id int,
    @time_start time,
    @time_end time,
    @max_participants int
AS
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM conference_day WHERE id = @id)
            BEGIN
                THROW 52000, 'Conference day with this Id doesn''t exists', 1
            END
        IF @time_start IS NOT NULL
            BEGIN
                UPDATE conference_day
                   SET time_start = @time_start
                 WHERE id = @id
            END
        IF @time_end IS NOT NULL
            BEGIN
                UPDATE conference_day
                   SET time_end = @time_end
                 WHERE id = @id
            END
        IF @max_participants IS NOT NULL
            BEGIN
                UPDATE conference_day
                   SET max_participants = @max_participants
                 WHERE id = @id
            END
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when changing conference day details: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO

/* Changes workshops details */
CREATE PROCEDURE [change_workshop_details]
    @id int,
    @max_participants int,
    @price decimal(6, 2),
    @start_time datetime,
    @end_time datetime
AS
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM workshop WHERE id = @id)
            BEGIN
                THROW 52000, 'Workshop with this Id doesn''t exists', 1
            END
        IF @max_participants IS NOT NULL
            BEGIN
                UPDATE workshop
                   SET max_participants = @max_participants
                 WHERE id = @id
            END
        IF @price IS NOT NULL
            BEGIN
                UPDATE workshop
                   SET price = @price
                 WHERE id = @id
            END
        IF @start_time IS NOT NULL
            BEGIN
                UPDATE workshop
                   SET start_time = @start_time
                 WHERE id = @id
            END
        IF @end_time IS NOT NULL
            BEGIN
                UPDATE workshop
                   SET end_time = @end_time
                 WHERE id = @id
            END
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when changing workshop details: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO

/* Changes number of booked tickets for conference day */
CREATE PROCEDURE [update_tickets_count]
    @id int,
    @full_price_ticket_count int,
    @reduced_priced_ticket_count int
AS
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM conference_day_booking WHERE id = @id)
            BEGIN
                THROW 52000, 'Conference day booking with this Id doesn''t exists', 1
            END
        IF @full_price_ticket_count IS NOT NULL
            BEGIN
                UPDATE conference_day_booking
                   SET full_price_ticket_count = @full_price_ticket_count
                 WHERE id = @id
            END
        IF @reduced_priced_ticket_count IS NOT NULL
            BEGIN
                UPDATE conference_day_booking
                   SET reduced_priced_ticket_count = @reduced_priced_ticket_count
                 WHERE id = @id
            END
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when updaiting tickets count: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO

/* Changes number of booked tickets for workshop */
CREATE PROCEDURE [update_workshop_ticket_counts]
    @id int,
    @full_price_ticket_count int,
    @reduced_priced_ticket_count int
AS
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM workshop_booking WHERE id = @id)
            BEGIN
                THROW 52000, 'Workshop booking with this Id doesn''t exists', 1
            END
        IF @full_price_ticket_count IS NOT NULL
            BEGIN
                UPDATE workshop_booking
                   SET full_price_ticket_count = @full_price_ticket_count
                 WHERE id = @id
            END
        IF @reduced_priced_ticket_count IS NOT NULL
            BEGIN
                UPDATE workshop_booking
                   SET reduced_priced_ticket_count = @reduced_priced_ticket_count
                 WHERE id = @id
            END
    END TRY
    BEGIN CATCH
        DECLARE @errorMessage nvarchar(2048);
        SET @errorMessage = 'Error when updating workshop ticket counts: ' + ERROR_MESSAGE();
        THROW 52000, @errorMessage, 1;
    END CATCH
GO