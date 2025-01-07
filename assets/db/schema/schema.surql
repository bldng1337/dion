USE DB APP;
USE NS APP;

DEFINE TABLE entry SCHEMAFULL;
DEFINE FIELD extensionid ON entry TYPE string;

DEFINE FIELD entryid ON entry TYPE string;
DEFINE FIELD url ON entry TYPE string;
DEFINE FIELD title ON entry TYPE string;
DEFINE FIELD status ON entry TYPE string;
DEFINE FIELD description ON entry TYPE string;
DEFINE FIELD language ON entry TYPE string;
DEFINE FIELD episodes ON entry TYPE array<object>;
DEFINE FIELD genres ON entry TYPE array<string>;
DEFINE FIELD alttitles ON entry TYPE array<string>;
DEFINE FIELD author ON entry TYPE array<string>;
DEFINE FIELD cover ON entry TYPE string;
DEFINE FIELD coverheader ON entry FLEXIBLE TYPE object;
DEFINE FIELD mediatype ON entry TYPE string;
DEFINE FIELD rating ON entry TYPE float;
DEFINE FIELD views ON entry TYPE int;
DEFINE FIELD length ON entry TYPE int;
DEFINE FIELD ui ON entry TYPE FLEXIBLE TYPE object;

DEFINE FIELD episodedata ON entry TYPE array<object>;