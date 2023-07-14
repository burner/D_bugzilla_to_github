module githubmigrationapi;

/*
"created_at": "2014-01-01T12:34:58Z",
    "closed_at": "2014-01-02T12:24:56Z",
    "updated_at": "2014-01-03T11:34:53Z",
    "assignee": "jonmagic",
    "milestone": 1,
    "closed": true,
    "labels": [
      "bug",
      "low"
    ]
  },
  "comments": [
    {
      "created_at": "2014-01-02T12:34:56Z",
      "body": "talk talk"
    }
*/

struct MigrationComments {
	string body_;
	DateTime created_at;
}

struct MigrationIssue {
	string title;
	string body_;
	DateTime created_at;
	Nullable!DateTime closed_at;
	DateTime updated_at;
	Nullable!string assignee;
	Nullable!bool closed;
	string[] labels;
	MigrationComments[] comments;
}
