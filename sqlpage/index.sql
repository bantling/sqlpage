-- Display validation errors
SELECT 'alert' AS component
      ,'Duplicate username' as title
      ,'The Username ' || :username || ' is already taken, choose another' as description
 WHERE :username IS NOT NULL
   AND EXISTS (SELECT 1 FROM users WHERE username = :username);

-- Insert submitted data
INSERT INTO users (
  username
 ,first_name
 ,last_name
)
SELECT :username
      ,:firstName
      ,:lastName
WHERE :username IS NOT NULL
 AND NOT EXISTS (SELECT 1 FROM users WHERE username = :username);

-- Display form input
SELECT 'form' AS component
      ,'Add a user' AS title;

SELECT 'username' as name
      ,'Username' as label
      ,TRUE as required;

SELECT 'firstName' as name
      ,'First Name' as label
      ,TRUE as required;

SELECT 'lastName' as name
      ,'Last Name' as label
      ,TRUE as required;

-- Display existing users
SELECT 'list' AS component
      ,'Users' AS title;

SELECT username AS title
      ,first_name || ' ' || last_name as description
      ,'user' as icon
  FROM users
 ORDER BY username;
