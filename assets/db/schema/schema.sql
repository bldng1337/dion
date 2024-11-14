CREATE TABLE "entry" (
	"id"	TEXT,
	"extensionid"	TEXT NOT NULL,
	"url"	TEXT NOT NULL,
	"title"	TEXT NOT NULL,
	"mediatype"	TEXT NOT NULL,
	"cover"	TEXT,
	"coverheader"	TEXT,
	"author"	TEXT,
	"rating"	REAL,
	"views"	INTEGER,
	"length"	INTEGER,
	"ui"	TEXT NOT NULL,
	"status"	TEXT,
	"description"	TEXT,
	"language"	TEXT,
	"alttitles"	TEXT,
	PRIMARY KEY("id")
)
--s
CREATE TABLE "entryxgenre" (
	"id"	INTEGER,
	"entry"	TEXT NOT NULL,
	"genre"	INTEGER NOT NULL,
	PRIMARY KEY("id"),
	FOREIGN KEY("entry") REFERENCES "entry"("id") ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY("genre") REFERENCES "genre"("id")
)
--s
CREATE TABLE "episode" (
	"id"	TEXT,
	"episodelist"	TEXT NOT NULL,
	"name"	TEXT NOT NULL,
	"url"	TEXT NOT NULL,
	"cover"	TEXT,
	"coverheader"	TEXT,
	"timestamp"	TEXT,
	PRIMARY KEY("id"),
	FOREIGN KEY("episodelist") REFERENCES "episodelist"("id") ON DELETE CASCADE ON UPDATE CASCADE
)
--s
CREATE TABLE "episodelist" (
	"id"	INTEGER,
	"title"	TEXT NOT NULL,
	"entry"	TEXT NOT NULL,
	PRIMARY KEY("id"),
	FOREIGN KEY("entry") REFERENCES "entry"("id") ON DELETE CASCADE ON UPDATE CASCADE
)
--s
CREATE TABLE "genre" (
	"id"	INTEGER,
	"genre"	TEXT NOT NULL,
	PRIMARY KEY("id")
)