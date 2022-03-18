module getopenissues;

import std.array;
import std.algorithm.searching;
import std.algorithm.iteration;
import std.algorithm.sorting;
import std.range : tee;
import std.uni : isNumber;
import std.net.curl;
import std.regex;
import std.stdio;
import std.conv;

auto fwd(string p, T)(T t) {
	writefln("%s %s", p, t);
	return t;
}

long[] getOpenIssuesImpl(string component) {
	string temp = `https://issues.dlang.org/buglist.cgi?component=` 
		~ component 
		~ `&limit=0&order=changeddate%20DESC%2Cbug_id&product=D&query_format=advanced&resolution=---`;

	string page = cast(string)get(temp);

	auto re = regex(`"show_bug.cgi\?id=[0-9]+"`);
	auto m = page.matchAll(re);

	return m
		.filter!(it => it.length > 0)
		.map!(it => it.front)
		.map!(it => it.find!(isNumber))
		.map!(it => it.until!(it => !it.isNumber()))
		.filter!(it => !it.empty)
		.map!(it => it.to!long())
		.array
		.sort
		.uniq
		.array;
}
