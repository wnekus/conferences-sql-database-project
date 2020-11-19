CREATE TABLE company
(
    id int IDENTITY PRIMARY KEY,
    name varchar (255),
    phone varchar (20),
    user_id int REFERENCES [user],
    CONSTRAINT check_company
        CHECK ([name] IS NOT NULL AND [phone] IS NOT NULL)
) GO

CREATE TABLE conference
(
    id int IDENTITY PRIMARY KEY,
    name varchar (255),
    description  text,
    date_start date,
    date_end date,
    CONSTRAINT check_conference
        CHECK ([date_start] IS NOT NULL AND [date_end] IS NOT NULL)
) GO

CREATE TABLE conference_day
(
    id int IDENTITY PRIMARY KEY,
    theme nvarchar (255),
    lecturer nvarchar (255),
    date date,
    time_start time,
    time_end time,
    max_participants int,
    conference_id int REFERENCES conference,
    student_discount int,
    CONSTRAINT check_conference_day
        CHECK ([theme] IS NOT NULL AND [time_start] IS NOT NULL AND [time_end] IS NOT NULL AND [max_participants] IS NOT NULL)
) GO

CREATE TABLE conference_day_booking
(
    id int IDENTITY PRIMARY KEY,
    booking_date datetime,
    cancel_date datetime,
    full_price_ticket_count int,
    reduced_priced_ticket_count int,
    conference_day_id int REFERENCES conference_day,
    user_id int REFERENCES [user],
    CONSTRAINT check_conference_day_booking
        CHECK ([full_price_ticket_count] >= 0 AND [reduced_priced_ticket_count] >= 0)
) GO

CREATE TABLE conference_day_registration
(
    id int IDENTITY PRIMARY KEY,
    registration_date datetime,
    cancel_date datetime,
    participant_id int REFERENCES participant,
    conference_day_booking_id int REFERENCES conference_day_booking,
    is_student bit
) GO

CREATE TABLE individual_user
(
    id int IDENTITY PRIMARY KEY,
    user_id int REFERENCES [user],
    name varchar (255),
    surname varchar (255),
    CONSTRAINT check_individual_user
        CHECK ([name] IS NOT NULL AND [surname] IS NOT NULL)
) GO

CREATE TABLE participant
(
    id int IDENTITY PRIMARY KEY,
    name varchar (255),
    surname varchar (255),
    PESEL varchar(11) UNIQUE,
    CONSTRAINT check_participant
        CHECK ([name] IS NOT NULL AND [surname] IS NOT NULL)
) GO

CREATE TABLE payment
(
    id int IDENTITY PRIMARY KEY,
    payment_date datetime,
    amount decimal (6, 2),
    conference_day_booking_id int REFERENCES conference_day_booking,
    user_id int REFERENCES [user]
) GO

CREATE TABLE price_level
(
    id int IDENTITY PRIMARY KEY,
    date_limit date,
    day_price decimal (6, 2),
    conference_day_id int REFERENCES conference_day
) GO

CREATE TABLE [user]
(
    id int IDENTITY PRIMARY KEY,
    login varchar (255) UNIQUE,
    password varchar (255),
    email varchar (255) UNIQUE,
    is_active bit
) GO

CREATE TABLE workshop
(
    id int IDENTITY PRIMARY KEY,
    name varchar (255),
    max_participants int,
    conference_day_id int REFERENCES conference_day,
    price decimal (6, 2),
    start_time datetime,
    end_time datetime,
    CONSTRAINT check_workshop
        CHECK ([name] IS NOT NULL AND [max_participants] IS NOT NULL AND [price] IS NOT NULL)
) GO

CREATE TABLE workshop_booking
(
    id int IDENTITY PRIMARY KEY,
    booking_date datetime,
    cancel_date datetime,
    full_price_ticket_count int,
    reduced_priced_ticket_count int,
    conference_day_booking_id int REFERENCES conference_day_booking,
    workshop_id int REFERENCES workshop,
    CONSTRAINT check_workshop_booking
        CHECK ([full_price_ticket_count] >= 0 AND [reduced_priced_ticket_count] >= 0)
) GO

CREATE TABLE workshop_registration
(
    id int IDENTITY PRIMARY KEY,
    registration_date datetime
    CONSTRAINT check_workshop_registration
        CHECK ([registration_date] IS NOT NULL),
    cancel_date datetime,
    workshop_booking_id int REFERENCES workshop_booking,
    conference_day_registration_id int REFERENCES conference_day_registration
) GO