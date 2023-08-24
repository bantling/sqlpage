-- Users who can log in to the system
CREATE TABLE IF NOT EXISTS users (
  relid INTEGER PRIMARY KEY AUTOINCREMENT
 ,username TEXT NOT NULL
 ,first_name TEXT NOT NULL
 ,last_name TEXT NOT NULL
);

CREATE UNIQUE INDEX users_username_uk ON users(username);
