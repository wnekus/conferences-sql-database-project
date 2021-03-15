/* Returns workers of company */
CREATE FUNCTION company_participants_list (@c_id int)
RETURNS TABLE AS
    RETURN
        SELECT p.*
          FROM company c
    INNER JOIN [user] u
            ON c.user_id = u.id
    INNER JOIN conference_day_booking cdb
            ON u.id = cdb.user_id
    INNER JOIN conference_day_registration cdr
            ON cdb.id = cdr.conference_day_booking_id
    INNER JOIN participant p
            ON cdr.participant_id = p.id
         WHERE c.id = @c_id
GO

/* Returns conference day participants info */
CREATE FUNCTION participant_conference_registration_info (@p_id int)
RETURNS TABLE AS
    RETURN
    SELECT cd.id,
           cdb.participant_id,
           cd.theme,
           cd.date
      FROM conference_day_registration cdb
INNER JOIN participant p
        ON cdb.participant_id = p.id
INNER JOIN conference_day_booking c
        ON cdb.conference_day_booking_id = c.id
INNER JOIN conference_day cd
        ON c.conference_day_id = cd.id
     WHERE participant_id = @p_id
       AND cdb.cancel_date IS NULL
GO

/* Returns workshop participants info */
CREATE FUNCTION participant_workshop_registration_info (@p_id int)
RETURNS TABLE AS
    RETURN
        SELECT cdr.participant_id,
               w.name,
               w.conference_day_id
          FROM conference_day_registration cdr
    INNER JOIN workshop_registration wr
            ON cdr.id = wr.conference_day_registration_id
    INNER JOIN workshop_booking wb
            ON wr.workshop_booking_id = wb.id
    INNER JOIN workshop w
            ON wb.workshop_id = w.id
         WHERE cdr.participant_id = @p_id
           AND cdr.cancel_date IS NULL
           AND wr.cancel_date IS NULL
GO

/* Returns info to generate identifier */
CREATE FUNCTION generate_participant_id (@cd_id int)
RETURNS TABLE AS
    RETURN
        SELECT p.name,
               p.surname,
               cdr.is_student
          FROM participant p
    INNER JOIN conference_day_registration cdr
            ON p.id = cdr.participant_id
    INNER JOIN conference_day_booking cdb
            ON cdr.conference_day_booking_id = cdb.id
         WHERE cdb.conference_day_id = @cd_id
GO

/* Returns cost of conference day */
CREATE FUNCTION get_conference_day_booking_cost (@id int)
RETURNS decimal(6, 2) AS
    RETURN
        SELECT (min (day_price) * full_price_ticket_count) +
               (min (day_price) * student_discount * reduced_priced_ticket_count)
          FROM conference_day_booking
    INNER JOIN price_level
            ON conference_day_booking.conference_day_id = price_level.conference_day_id
    INNER JOIN conference_day
            ON conference_day_booking.conference_day_id = conference_day.id
         WHERE conference_day_booking.id = @id
           AND price_level.date_limit > conference_day_booking.booking_date
      GROUP BY full_price_ticket_count,
               reduced_priced_ticket_count,
               student_discount
GO

/* Returns workshop cost */
CREATE FUNCTION get_workshop_booking_cost (@id int)
RETURNS decimal(6, 2) AS
    RETURN
        SELECT (price * full_price_ticket_count ) +
               (price * student_discount * reduced_priced_ticket_count)
          FROM workshop_booking
    INNER JOIN workshop
            ON workshop_booking.workshop_id = workshop.id
    INNER JOIN conference_day cd
            ON workshop.conference_day_id = cd.id
         WHERE workshop_booking.id = @id
      GROUP BY price,
               full_price_ticket_count,
               reduced_priced_ticket_count,
               student_discount)
GO

/* Returns conference day and workshop cost */
CREATE FUNCTION get_total_cost_of_booking (@id int)
RETURNS decimal(6, 2) AS
    DECLARE @workshop_id int = (SELECT id
                                  FROM workshop
                                 WHERE conference_day_id = @id)
    RETURN dbo.get_conference_day_booking_cost(@id) +
           dbo.get_workshop_booking_cost(@workshop_id)
GO

/* Returns ticket price depending on reservation time */
CREATE FUNCTION get_conference_day_booking_ticket_price (@id int)
RETURNS decimal(6, 2) AS
    RETURN
        SELECT min(pl.day_price)
          FROM conference_day_booking cdb
    INNER JOIN conference_day cd
            ON cdb.conference_day_id = cd.id
    INNER JOIN price_level pl
            ON cd.id = pl.conference_day_id
           AND cdb.booking_date < pl.date_limit
         WHERE cdb.id = @id
GO

/* Returns workshop price */
CREATE FUNCTION get_workshop_price_by_id (@id int)
RETURNS decimal(6, 2) AS
    RETURN
        SELECT price
          FROM workshop
         WHERE id = @id
GO

/* Returns number of free slots for conference day */
CREATE FUNCTION get_conference_day_free_places (@id int)
RETURNS int AS
    RETURN
        SELECT max_participants -
               ISNULL(sum(full_price_ticket_count), 0) -
               ISNULL(sum(reduced_priced_ticket_count), 0)
          FROM conference_day
LEFT OUTER JOIN conference_day_booking
            ON conference_day.id = conference_day_booking.conference_day_id
         WHERE conference_day. id = @id
           AND conference_day_booking.cancel_date IS NULL
      GROUP BY conference_day.id,
               conference_day.max_participants
GO

/* Returns number of free slots for workshop */
CREATE FUNCTION get_workshop_free_places (@id int)
RETURNS int AS
    RETURN
        SELECT max_participants -
               ISNULL(sum(full_price_ticket_count), 0) -
               ISNULL(sum(reduced_priced_ticket_count), 0)
          FROM workshop
     LEFT JOIN workshop_booking
            ON workshop.id = workshop_booking.workshop_id
         WHERE workshop.id = @id AND workshop_booking. cancel_date IS NULL
      GROUP BY workshop.id,
               workshop.max_participants
END

/* Returns payment done for conferences */

CREATE FUNCTION get_payment_done (@id int)
RETURNS decimal(6, 2) AS
    RETURN
        SELECT sum(amount)
          FROM payment
         WHERE conference_day_booking_id = @id
GO

/* Returns payment undone for conference */
CREATE FUNCTION get_payment_undone (@id int)
RETURNS decimal(6, 2) AS
    RETURN
        dbo.get_total_cost_of_booking(@id) - dbo.get_payment_done(@id)
GO

/* Returns student discount for conference */
CREATE FUNCTION get_student_discount (@id int)
RETURNS int AS
    DECLARE @sd int
    SET @sd = 50
    IF(SELECT min(cd. student_discount)
         FROM conference_day_booking cdb
   INNER JOIN conference_day cd
           ON cdb.conference_day_id = cd.id
        WHERE cdb.id = 1) IS NOT NULL
        SET @sd =  SELECT min(cd.student_discount)
                     FROM conference_day_booking cdb
               INNER JOIN conference_day cd
                       ON cdb.conference_day_id = cd.id
                    WHERE cdb.id = @id
   RETURN SELECT @sd
GO
