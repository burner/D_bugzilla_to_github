module githubmigrationapi;

import std.array : array, empty;
import std.algorithm.searching : canFind;
import std.algorithm.iteration : map;
import std.format : format;
import std.json;
import std.conv : to;

import core.thread;
import core.time;

import std.datetime;
import std.typecons : Nullable;
import std.stdio;
import std.string;

import requests;

import app : BugIssue;
import markdown;
import rest;
import json;
import allpeople;
import graphql;
import cliargs;

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

struct Migration {
	MigrationIssue issue;
	MigrationComments[] comments;
}

struct MigrationComments {
	string body_;
	DateTime created_at;
}

struct MigrationIssue {
	string title;
	string body_;
	DateTime created_at;
	//Nullable!DateTime closed_at;
	DateTime updated_at;
	Nullable!string assignee;
	bool closed;
	string[] labels;
}

MigrationComments commentToMigration(Comment c, ref AllPeopleHandler aph) {
	MigrationComments ret;
	ret.created_at = cast(DateTime)c.creation_time;
	AllPeople* ap = c.creator in aph.byEmail;
	string header = format("#### %s%s commented on %s\n\n", c.creator
				, ap is null 
					? "" 
					: " (@" ~ (*ap).githubUser ~ ")"
				, c.time.toISOExtString());

	ret.body_ = header ~ "\n\n" ~ c.text;
	return ret;
}

Migration bugToMigration(Bug b, ref AllPeopleHandler aph, Label[string] labelsAA
		, const(string[]) toIncludeKeys) 
{
	AllPeople* ap = b.creator_detail.id in aph.byBugzillaId;

	MigrationIssue ret;
	ret.title = b.summary;
	ret.created_at = cast(DateTime)b.creation_time;
	ret.assignee = ap !is null 
			&& !(*ap).githubUser.empty 
			&& theArgs().mentionPeopleInGithubAndPostOnBugzilla
		? (*ap).githubUser
		: b.creator_detail.name;
	ret.assignee = "burner";
	ret.closed = false;
	ret.body_ = markdownBody(b, aph);
	if(!b.attachments.isNull() && !b.attachments.get().empty) {
		ret.body_ ~= "\n\n\n**!!!There are attachements in the bugzilla issue"
			~ " that have not been copied over!!!**";
	}
	ret.updated_at = cast(DateTime)b.last_change_time;
	static foreach(mem; __traits(allMembers, Bug)) {{
		if(canFind(toIncludeKeys, mem)) {
			alias MT = typeof(__traits(getMember, Bug, mem));
			static if(is(MT == string)) {{
				auto has = __traits(getMember, b, mem);	
				if(has in labelsAA) {
					ret.labels ~= labelsAA[has].name;
				}
			}} else static if(is(MT == string[])) {{
				auto has = __traits(getMember, b, mem);	
				foreach(it; has) {
					if(it in labelsAA) {
						ret.labels ~= labelsAA[it].name;
					}
				}
			}}
		}
	}}
	Migration actualReturn;
	actualReturn.issue = ret;
	actualReturn.comments = b.comments.get([])[1 .. $]
		.map!(it => commentToMigration(it, aph))
		.array;

	return actualReturn;
}

CreateIssueResult createMigrationissue(Migration mi, string githubToken) {
	JSONValue jv = toJson(mi);
	//writeln(jv.toPrettyString());
	Request rq = Request();
	string uri = "https://api.github.com/repos/%s/%s/import/issues"
				.format(theArgs().githubOrganization
					, theArgs().githubProject);
	rq.addHeaders(["Accept": "application/vnd.github.golden-comet-preview+json"
			, "Authorization" : "token " ~ githubToken
	]);
	Response re;
	string t;
	JSONValue ret;
	try {
		re = rq.post(uri, jv.toPrettyString());
		t = re.responseBody.to!string();
		ret = parseJSON(t);
		//writefln("\n\n%s\n\n", ret.toPrettyString());
	} catch(Exception e) {
		throw new Exception(format(
				"request: '%s'\nvars: '%s'\nret: '%s'",
				re, jv.toPrettyString(), t),
				__FILE__, __LINE__, e);
	}

	return tFromJson!CreateIssueResult(ret);	
}

struct MigrationError {
	string location;
	string resource;
	string field;
	string value;
	string code;
	string url;
	string created_at;
	string updated_at;
}

struct MigrationResult {
	long id;
	string status;
	string url;
	string issue_url;
	Nullable!(MigrationError[]) errors;
}

MigrationResult getImportStatus(BugIssue b, string githubToken) {
	Request rq = Request();
	string uri = "https://api.github.com/repos/%s/%s/import/issues/%s"
				.format(theArgs().githubOrganization
					, theArgs().githubProject
					, b.githubIssue.id.get(0));
	rq.addHeaders(["Accept": "application/vnd.github.golden-comet-preview+json"
			, "Authorization" : "token " ~ githubToken
	]);
	Response re;
	string t;
	JSONValue ret;
	Exception exp;
	foreach(_; 0 .. 2) {
		try {
			re = rq.get(uri);
			t = re.responseBody.to!string();
			ret = parseJSON(t);
			return tFromJson!MigrationResult(ret);	
		} catch(Exception e) {
			if(e.toString().indexOf("API rate limit exceeded")) {
				writefln("Sleeping for an 61 minutes hit rate limit in %s"
						, __FUNCTION__);
				Thread.sleep(dur!"minutes"(61));
			}
			exp = new Exception(format(
					"request: '%s'\nret: '%s'",
					re, t),
					__FILE__, __LINE__, e);
		}
	}
	throw exp is null
		? new Exception("Should get here")
		: exp;


}
