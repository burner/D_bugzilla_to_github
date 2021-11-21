module rest;

import std.array;
import std.json;
import std.algorithm.sorting;
import std.algorithm.iteration;
import std.stdio;
import std.conv : to;
import std.format;
import std.net.curl;
import std.traits;
import std.range : ElementEncodingType;
import std.exception;
import std.string : stripRight;
import std.typecons : Nullable, nullable;
import std.datetime.systime;

import json;

import requests;

struct Person {
	long id;
	string email;
	string name;
	string real_name;
}

struct Bug {
	int id;
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

Bug[] parseBugs(JSONValue js) {
	if(js.type() == JSONType.object && "code" in js) {
		return [];
	}
	return JSONValue(js["bugs"].arrayNoRef()
		.map!(filterNonFound)
		.filter!(it => !it.isNull())
		.map!(it => it.get())
		.array)
		.tFromJson!(Bug[])();
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

	auto c = "comments" in *idJ;
	if(c is null) {
		return Nullable!(JSONValue).init;
	}
	JSONValue v = *c;
	return nullable(v);
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

JSONValue getComment(long id) {
	string url = "https://issues.dlang.org/rest/bug/%d/comment";
	string withId = format(url, id);
	auto content = getContent(withId).to!string().parseJSON();
	return content;
}

unittest {
	string h = `
{"bugs":[{"alias":[],"assigned_to":"bugzilla","assigned_to_detail":{"email":"bugzilla","id":2,"name":"bugzilla","real_name":"Walter Bright"},"blocks":[],"cc":[],"cc_detail":[],"classification":"Unclassified","component":"phobos","creation_time":"2007-02-22T23:12:19Z","creator":"wbaxter","creator_detail":{"email":"wbaxter","id":113,"name":"wbaxter","real_name":"Bill Baxter"},"deadline":null,"depends_on":[],"dupe_of":null,"flags":[],"groups":[],"id":1000,"is_cc_accessible":true,"is_confirmed":true,"is_creator_accessible":true,"is_open":false,"keywords":[],"last_change_time":"2014-02-16T15:23:56Z","op_sys":"Windows","platform":"x86","priority":"P2","product":"D","qa_contact":"","resolution":"FIXED","see_also":[],"severity":"normal","status":"RESOLVED","summary":"writefln fails on nested arrays","target_milestone":"---","url":"","version":"D1 (retired)","whiteboard":""}],"faults":[]}`;

	auto js = parseJSON(h);
	auto bugs = tFromJson!(Bug[])(js["bugs"]);
	writeln(bugs);
}
