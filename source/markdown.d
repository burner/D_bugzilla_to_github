module markdown;

import std.algorithm.iteration : filter, joiner, map, fold, uniq, splitter;
import std.algorithm.searching : canFind, endsWith, startsWith;
import std.algorithm.sorting : sort;
import std.array;
import std.conv : to;
import std.exception;
import std.format;
import std.stdio;
import std.typecons;

import rest;
import cliargs;
import allpeople;

@safe:

struct Markdowned {
@safe:
	string title;
	string header;
	string comments;

	string toString() {
		return this.title ~ this.header ~ this.comments;
	}
}

bool isCodeLineEnding(string l) {
	return l.endsWith("}")
		|| l.endsWith("{")
		|| l.endsWith(";")
		|| l.endsWith("@safe")
		|| l.endsWith("@trusted")
		|| l.endsWith("@system")
		|| l.startsWith("@safe")
		|| l.startsWith("@trusted")
		|| l.startsWith("@system")
		|| l.endsWith("const")
		|| l.endsWith("inout")
		|| l.endsWith("immutable")
		|| l.endsWith("pure")
		|| l.startsWith("struct")
		|| l.startsWith("class");
}

bool isLineComment(string l) {
	return l.canFind("//") && !l.canFind("http");
}

bool isCode(string l) {
	return isCodeLineEnding(l) || isLineComment(l);
}

struct DConfFinder {
	string[] lines;
	bool isDcode;
	string[] reset() {
		string[] ret = lines;
		this.lines = [];
		this.isDcode = false;
		return ret;
	}

	bool insert(string line) {
		const isC = isCode(line);
		const bothNotEmpty = this.lines.length == 0
			? false
			: isCode(this.lines[$ - 1]) && line.empty;
		//writefln("%s %s :: %s", isC, bothNotEmpty, line);
		this.isDcode = isC || bothNotEmpty;
		if(this.isDcode) {
			this.lines ~= line;
		}
		return this.isDcode;
	}
}

unittest {
	string t = `
union T {int x; int *y;}

void main() @safe
{
    T t;
    t.x = 5;
    // *t.y = 5; // error in @safe, but not in @trusted
}
`;
	DConfFinder dcf;
	long idx;
	foreach(l; t.splitter("\n")) {
		assert(dcf.insert(l), l ~ " " ~ to!string(idx));
		++idx;
	}

	assert(dcf.isDcode);
}

Markdowned toMarkdown(Bug b, ref AllPeopleHandler aph) {
	Markdowned ret;
	AllPeople* ap = b.creator_detail.id in aph.byBugzillaId;
	ret.title = b.summary;
	ret.header = markdownBody(b, aph);

	ret.header ~= "### Comments\n\n";

	Comment[] comments = b.comments.get();
	ret.comments = comments[1 .. $]
		.map!(c => toMarkdown(c, false, aph))
		.joiner("\n\n")
		.to!string();

	return ret;
}

string markdownBody(Bug b, ref AllPeopleHandler aph) {
	AllPeople* ap = b.creator_detail.id in aph.byBugzillaId;
	string ret = () @trusted { 
		return format("## %s%s reported this on %s\n\n"
				, b.creator
				, ap is null 
					? "" 
					: theArgs().mentionPeopleInGithubAndPostOnBugzilla
						? " (@" ~ (*ap).githubUser ~ ")"
						: " (" ~ (*ap).githubUser ~ ")"
				, b.creation_time.toISOExtString()
			)
		~ format("### Transfered from https://issues.dlang.org/show_bug.cgi?id=%s\n\n"
				, b.id
			)
		~ (b.cc_detail.empty
			? ""
			: format("### CC List\n\n%--(* %s\n%)\n\n"
					, b.cc_detail.map!((c) {
						AllPeople* cc = c.email in aph.byEmail;
						return cc is null || !(*cc).githubUser.empty
							? c.name
							: theArgs().mentionPeopleInGithubAndPostOnBugzilla
								? format("%s (@%s)", c.name, (*cc).githubUser)
								: format("%s (%s)", c.name, (*cc).githubUser);
					})
				)
			);
	}();

	ret ~= "### Description\n\n";
	enforce(!b.comments.isNull(), format("Bug %s has no comments", b.id));
	Comment[] comments = b.comments.get();
	if(comments.empty) {
		ret ~= "No description was given";
	} else {
		ret ~= toMarkdown(comments.front, true, aph);
	}
	return ret;
}

string toMarkdown(Comment c, const bool noHeader, ref AllPeopleHandler aph) {
	AllPeople* ap = c.creator in aph.byEmail;
	string header = noHeader
		? ""
		: format("#### %s%s commented on %s\n\n", c.creator
				, ap is null 
					? "" 
					: " (" ~ (*ap).githubUser ~ ")"
				, c.time.toISOExtString());
	string body_ = c.text
		.replace("\\n", "\n")
		.replace("In reply to comment #", "In reply to comment ");
	/*
	string newBody;
	DConfFinder dcf;
	foreach(l; body_.splitter("\n")) {
		const wasCode = dcf.isDcode;
		const isC = dcf.insert(l);

		if(wasCode && !isC) {
			string[] lines = dcf.reset();
			string fstr = lines.length > 4
				? "```dlang\n%--(%s\n%)\n```\n"
				: "%--(%s\n%)\n";
			newBody ~= format(fstr, lines);
		} else if(!wasCode && !isC) {
			newBody ~= l ~ "\n";
			dcf.reset();
		}
	}
	if(dcf.isDcode) {
		newBody ~= format("```dlang\n%--(%s\n%)\n```\n", dcf.reset);
	}*/

	return header ~ body_;
}
