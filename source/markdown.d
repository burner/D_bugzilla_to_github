module markdown;

import std.array;
import std.conv : to;
import std.stdio;
import std.exception;
import std.algorithm.iteration : filter, joiner, map, fold, uniq;
import std.algorithm.searching : canFind;
import std.algorithm.sorting : sort;
import std.format;
import std.typecons;

import rest;

struct Markdowned {
	string title;
	string header;
	string comments;

	string toString() {
		return this.title ~ this.header ~ this.comments;
	}
}

Markdowned toMarkdown(Bug b) {
	Markdowned ret;
	ret.title = b.summary;
	ret.header = format("## %s reported this on %s\n\n"
				, b.creator, b.creation_time.toISOExtString()
			)
		~ format("### Transfered from https://issues.dlang.org/show_bug.cgi?id=%s\n\n"
				, b.id
			)
		~ (b.cc_detail.empty
			? ""
			: format("### CC List\n\n%--(* %s\n%)\n\n"
					, b.cc_detail.map!(c => c.name)
				)
			);

	ret.header ~= "### Description\n\n";
	enforce(!b.comments.isNull(), format("Bug %s has no comments", b.id));
	Comment[] comments = b.comments.get();
	enforce(!comments.empty, format("Bug %s has no description", b.id));
	ret.header ~= toMarkdown(comments.front, true);

	ret.header ~= "### Comments\n\n";
	ret.comments = comments[1 .. $]
		.map!(c => toMarkdown(c, false))
		.joiner("\n\n")
		.to!string();

	return ret;
}

string toMarkdown(Comment c, const bool noHeader) {
	string header = noHeader
		? ""
		: format("#### %s commented on %s\n\n", c.creator
				, c.time.toISOExtString());
	string body_ = c.text.replace("\\n", "\n");
	return header ~ body_;
}
