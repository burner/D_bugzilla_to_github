module githubmigrationapi;

import std.array : array;
import std.algorithm.searching : canFind;
import std.algorithm.iteration : map;
import std.format : format;
import std.datetime;
import std.typecons : Nullable;
import rest;
import allpeople;
import graphql : Label;

//
// https://gist.github.com/jonmagic/5282384165e0f86ef105
//

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

MigrationComments commentToMigration(Comment c, ref AllPeopleHandler aph) {
	MigrationComments ret;
	AllPeople* ap = c.creator in aph.byEmail;
	string header = format("#### %s%s commented on %s\n\n", c.creator
				, ap is null 
					? "" 
					: " (" ~ (*ap).githubUser ~ ")"
				, c.time.toISOExtString());

	ret.body_ = header ~ "\n\n" ~ c.text;
	return ret;
}

MigrationIssue bugToMigration(Bug b, ref AllPeopleHandler aph, Label[string] labelsAA
		, const(string[]) toIncludeKeys) 
{
	MigrationIssue ret;
	ret.title = b.summary;
	ret.created_at = cast(DateTime)b.creation_time;
	ret.assignee = b.assigned_to;
	ret.updated_at = cast(DateTime)b.last_change_time;
	static foreach(mem; __traits(allMembers, Bug)) {{
		if(canFind(toIncludeKeys, mem)) {
			alias MT = typeof(__traits(getMember, Bug, mem));
			static if(is(MT == string)) {{
				auto has = __traits(getMember, b, mem);	
				if(has in labelsAA) {
					ret.labels ~= labelsAA[has].id;
				}
			}} else static if(is(MT == string[])) {{
				auto has = __traits(getMember, b, mem);	
				foreach(it; has) {
					if(it in labelsAA) {
						ret.labels ~= labelsAA[it].id;
					}
				}
			}}
		}
	}}
	ret.comments = b.comments.get([])
		.map!(it => commentToMigration(it, aph))
		.array;
	return ret;
}
