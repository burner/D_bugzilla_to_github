module analysis;

import std.algorithm.iteration;
import std.algorithm.sorting;
import std.array;
import std.conv : to;
import std.datetime.systime;
import std.exception;
import std.format;
import std.json;
import std.net.curl;
import std.range : ElementEncodingType;
import std.stdio;
import std.string : stripRight;
import std.traits;
import std.typecons : Nullable, nullable;

import json;
import rest;

struct BugAnalysis {
	string[] classification;
	string[] component;
	string[] flags;
	string[] groups;
	string[] keywords;
	string[] op_sys;
	string[] platform;
	string[] priority;
	string[] product;
	string[] resolution;
	string[] severity;
	string[] status;
	string[] target_milestone;
}

BugAnalysis doBugAnalysis(R)(R r) {
	BugAnalysis ret;
	foreach(it; r) {
		ret = join(ret, it);
	}
	return ret;
}

BugAnalysis join(BugAnalysis ba, Bug b) {
	static foreach(mem; FieldNameTuple!BugAnalysis) {{
		__traits(getMember, ba, mem) ~= __traits(getMember, b, mem);
		__traits(getMember, ba, mem) =
			__traits(getMember, ba, mem).sort.uniq.array;
	}}
	return ba;
}

struct CommentAnalysis {
	long attachment_count;
	long is_private_count;
	long is_markdown_count;
	string[] tags;
}

CommentAnalysis join(CommentAnalysis ca, Comment c) {
	ca.attachment_count += c.attachment_id.isNull() ? 0 : 1;
	ca.is_private_count += c.is_private ? 1 : 0;
	ca.is_markdown_count += c.is_markdown.isNull() ? 0 : 1;
	ca.tags = (ca.tags ~ c.tags).sort.uniq.array;
	return ca;
}

CommentAnalysis doCommentAnalysis(R)(R r) {
	CommentAnalysis ret;
	foreach(it; r) {
		ret = join(ret, it);
	}
	return ret;
}
