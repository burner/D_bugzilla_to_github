module rest;

import std.algorithm.iteration;
import std.algorithm.sorting;
import std.array;
import std.conv : to;
import std.datetime.date;
import std.datetime.systime;
import std.exception;
import std.format;
import std.json;
import std.net.curl;
import std.range : ElementEncodingType, chunks;
import std.stdio;
import std.string : stripRight;
import std.traits;
import std.typecons : Nullable, nullable;

import json;
import getopenissues;

import requests;

struct Person {
	long id;
	string email;
	string name;
	string real_name;

	JSONValue toJSON() const {
		JSONValue ret = JSONValue(
				[ "id" : JSONValue(this.id)
				, "email" : JSONValue(this.email)
				, "name" : JSONValue(this.name)
				, "real_name" : JSONValue(this.real_name)]);
		return ret;
	}
}

struct Bug {
	long id;
	Nullable!SysTime actual_time;
	Nullable!(long[]) alias_;
	string assigned_to;
	Person assigned_to_detail;
	long[] blocks;
	string[] cc;
	Person[] cc_detail;
	string classification;
	string component;
	SysTime creation_time;
	string creator;
	Person creator_detail;
	Nullable!(SysTime) deadline;
	long[] depends_on;
	Nullable!long dupe_of;
	Nullable!double estimated_time;
	string[] flags;
	string[] groups;
	bool is_cc_accessible;
	bool is_confirmed;
	bool is_open;
	bool is_creator_accessible;
	string[] keywords;
	SysTime last_change_time;
	string op_sys;
	string platform;
	string priority;
	string product;
	string qa_contact;
	Nullable!Person qa_contact_detail;
	Nullable!double remaining_time;
	string resolution;
	long[] see_also;
	string severity;
	string status;
	string summary;
	string target_milestone;
	Nullable!string update_token;
	string url;
	string version_;
	string whiteboard;

	// joined in later
	Nullable!(Comment[]) comments;
	Nullable!(Attachment[]) attachments;

	Nullable!(Date) lastTouched;
}

struct Attachment {
	long id;
	string data;
	long size;
	SysTime  creation_time;
	SysTime last_change_time;
	long bug_id;
	string file_name;
	string summary;
	string content_type;
	bool is_private;
	bool is_obsolete;
	bool is_patch;
	string creator;
	string[] flags;
}


struct Comment {
	long id;
	SysTime time;
	string text;
	long bug_id;
	long count;
	Nullable!long attachment_id;
	bool is_private;
	Nullable!bool is_markdown;
	string[] tags;
	string creator;
	SysTime creation_time;
}

struct Token {
	string token;
	long id;
}

Token bugzillaLogin(string username, string password) {
	string url = "https://issues.dlang.org/rest/login?login=%s&password=%s";
	string withId = format(url, username, password);
	return getContent(withId).to!string().parseJSON()
		.tFromJson!(Token)();
}

Bug[] parseBugs(JSONValue js) {
	if(js.type() == JSONType.object && "code" in js) {
		return [];
	}
	const b = "bugs";
	return b in js
		? JSONValue(js["bugs"].arrayNoRef()
			.map!(filterNonFound)
			.filter!(it => !it.isNull())
			.map!(it => it.get())
			.array)
			.tFromJson!(Bug[])()
		: [ js.tFromJson!(Bug)() ];
}

Nullable!JSONValue extractCommentArray(JSONValue js) {
	auto b = "bugs" in js;
	if(b is null && b.type() == JSONType.array) {
		return Nullable!(JSONValue).init;
	}
	string[] keys = b.objectNoRef().keys();
	if(keys.length != 1 && keys[0] !in *b) {
		return Nullable!(JSONValue).init;
	}
	auto idJ = keys[0] in *b;

	enforce((*idJ).type == JSONType.object, js.toPrettyString());
	auto c = "comments" in *idJ;
	if(c is null) {
		return Nullable!(JSONValue).init;
	}
	JSONValue v = *c;
	return nullable(v);
}

Nullable!JSONValue extractAttachmentArray(JSONValue js) {
	auto b = "bugs" in js;
	if(b is null && b.type() == JSONType.array) {
		return Nullable!(JSONValue).init;
	}
	string[] keys = b.objectNoRef().keys();
	if(keys.length != 1 && keys[0] !in *b) {
		return Nullable!(JSONValue).init;
	}
	auto idJ = keys[0] in *b;

	if(idJ !is null) {
		JSONValue r = *idJ;
		return nullable(r);
	} else {
		return Nullable!(JSONValue).init;
	}
}

Comment[] parseComment(JSONValue js) {
	if(js.type() == JSONType.object && "code" in js) {
		return [];
	}
	auto a = extractCommentArray(js);
	return a.isNull()
		? []
		: tFromJson!(Comment[])(a.get());
}

Attachment[] parseAttachment(JSONValue js) {
	if(js.type() == JSONType.object && "attachment" in js) {
		return [];
	}
	auto a = extractAttachmentArray(js);
	if(!a.isNull()) {
		//writefln("Attachments\n%s", a.get().toPrettyString());
	}
	return a.isNull()
		? []
		: tFromJson!(Attachment[])(a.get());
}

Nullable!JSONValue filterNonFound(JSONValue js) {
	return js.type() == JSONType.object && "code" in js
		? Nullable!(JSONValue).init
		: nullable(js);
}

JSONValue getBug(long id) {
	string url = "https://issues.dlang.org/rest/bug/%d";
	string withId = format(url, id);
	auto content = getContent(withId).to!string().parseJSON();
	return content;
}

JSONValue getBugs(long[] ids) {
	string url = "https://issues.dlang.org/rest/bug?id=%(%s,%)";
	string withId = format(url, ids);
	auto content = getContent(withId).to!string().parseJSON();
	return content;
}

JSONValue postComment(long issueId, string comment, string token) {
	string url = "https://issues.dlang.org/rest/bug/%d/comment";
	string withId = format(url, issueId);
	writeln(url);
	string ret = postContent(withId
		, queryParams("comment", comment
			, "token", token)
		).to!string();
	writeln(ret);
	return ret.to!string().parseJSON();
}

JSONValue getComment(long id) {
	foreach(r; 0 .. 2) {
		try {
			string url = "https://issues.dlang.org/rest/bug/%d/comment";
			string withId = format(url, id);
			auto content = getContent(withId).to!string().parseJSON();
			return content;
		} catch(TimeoutException t) {
			writefln("getComment timeout exception for %s", id);
		}
	}
	return JSONValue.init;
}

JSONValue getAttachments(long bugId) {
	string url = "https://issues.dlang.org/rest/bug/%d/attachment";
	string withId = format(url, bugId);
	foreach(r; 0 .. 2) {
		try {
			auto content = getContent(withId).to!string().parseJSON();
			return content;
		} catch(TimeoutException t) {
			writefln("getAttachments timeout exception for %s", bugId);
		}
	}
	return JSONValue.init;
}

unittest {
	string h = `
{"bugs":[{"alias":[],"assigned_to":"bugzilla","assigned_to_detail":{"email":"bugzilla","id":2,"name":"bugzilla","real_name":"Walter Bright"},"blocks":[],"cc":[],"cc_detail":[],"classification":"Unclassified","component":"phobos","creation_time":"2007-02-22T23:12:19Z","creator":"wbaxter","creator_detail":{"email":"wbaxter","id":113,"name":"wbaxter","real_name":"Bill Baxter"},"deadline":null,"depends_on":[],"dupe_of":null,"flags":[],"groups":[],"id":1000,"is_cc_accessible":true,"is_confirmed":true,"is_creator_accessible":true,"is_open":false,"keywords":[],"last_change_time":"2014-02-16T15:23:56Z","op_sys":"Windows","platform":"x86","priority":"P2","product":"D","qa_contact":"","resolution":"FIXED","see_also":[],"severity":"normal","status":"RESOLVED","summary":"writefln fails on nested arrays","target_milestone":"---","url":"","version":"D1 (retired)","whiteboard":""}],"faults":[]}`;

	auto js = parseJSON(h);
	auto bugs = tFromJson!(Bug[])(js["bugs"]);
	writeln(bugs);
}

import core.thread;

class Getter : Thread {
	Bug[] rslt;
	BugDate[] ids;

	this(BugDate[] ids) {
		this.ids = ids;
		super(&run);
	}

	void run() {
		long[] issueIds = this.ids.map!(it => it.id).array;
		writefln("download issues %(%s,%)", issueIds);
		auto js = getBugs(issueIds);
		this.rslt = parseBugs(js);
		outer: foreach(ref r; this.rslt) {
			foreach(bd; this.ids) {
				if(r.id == bd.id) {
					r.lastTouched = bd.date;
					continue outer;
				}
			}
		}
	}
}

Bug[] downloadAsChunks(BugDate[] ids, ulong chunkSize) {
	auto chks = chunks(ids, chunkSize);
	Getter[] getter = chks
		.map!(chk => cast(Getter)new Getter(chk))
		.array;

	foreach(it; getter) {
		it.start();
		it.join();
	}

	return getter
		.map!(it => it.rslt)
		.joiner
		.array;
}

class GetCommentAttachments : Thread {
	Bug rslt;

	this(Bug input) {
		this.rslt = input;
		super(&run);
	}

	void run() {
		this.rslt.attachments = getAttachments(this.rslt.id).parseAttachment();
		this.rslt.comments = getComment(this.rslt.id).parseComment();
	}
}

Bug[] downloadCommentsAndAttachments(Bug[] bugs, ulong chunkSize) {
	auto chks = chunks(bugs, chunkSize);
	Bug[] ret;
	foreach(chk; chks) {
		writefln("download comments and attachements for %(%s,%)", chk.map!(i => i.id));
		GetCommentAttachments[] getter = chk
			.map!(it => cast(GetCommentAttachments)new GetCommentAttachments(it).start())
			.array;

		foreach(it; getter) {
			it.join();
		}
		ret ~= getter
			.map!(it => it.rslt)
			.array;
	}
	return ret;
}
