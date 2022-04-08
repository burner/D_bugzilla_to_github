module getopenissues;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.algorithm.sorting;
import std.array;
import std.conv;
import std.datetime;
import std.net.curl;
import std.range : tee;
import std.regex;
import std.stdio;
import std.string;
import std.range;
import std.uni : isNumber;

@safe private:

auto fwd(string p, T)(T t) {
	writefln("%s %s", p, t);
	return t;
}

public struct BugDate {
	long id;
	Date date;
}

public BugDate[] getOpenIssuesImpl(string component) {
	string temp = `https://issues.dlang.org/buglist.cgi?component=` 
		~ component 
		~ `&limit=0&order=changeddate%20DESC%2Cbug_id&product=D&query_format=advanced&resolution=---`;

	string page = () @trusted { return cast(string)get(temp); }();
	Date[] d = splitDateTimes(page);
	long[] i = splitIds(page);
	assert(d.length == i.length, format("%s %s", d.length, i.length));
	return zip(i, d)
		.map!(id => BugDate(id[0], id[1]))
		.array
		.uniq
		.array;
}

long[] splitIds(string page) {
	enum re = ctRegex!(`"show_bug.cgi\?id=[0-9]+"`);
	auto m = page.matchAll(re);

	return m
		.filter!(it => it.length > 0)
		.map!(it => it.front)
		.map!(it => it.find!(isNumber))
		.map!(it => it.until!(it => !it.isNumber()))
		.filter!(it => !it.empty)
		.map!(it => it.to!long())
		.uniq
		.array;
}

Date[] splitDateTimes(string page) {
	const dtLine = `<td class="bz_changeddate_column nowrap">`;
	return page.splitter("\n")
		.filter!(l => l.indexOf(dtLine) != -1)
		.map!(l => l.replace(dtLine, ""))
		.map!(l => l.strip())
		.filter!(l => !l.empty)
		.map!(w => toDateTime(w))
		.array;
}

Date toDateTime(string s) {
	enum re = ctRegex!("([0-9]{4})-([0-9]{2})-([0-9]{2})");
	auto m = s.matchFirst(re);
	return m.empty
		? fromWord(s)
		: fromRegex(m);
}

Date fromRegex(Captures!string m) {
	auto c = m.captures();
	c.popFront();
	Date ret;
	ret.year = c.front.to!int();
	c.popFront();
	ret.month = c.front.stripLeft("0").to!ubyte().to!Month();
	c.popFront();
	ret.day = c.front.stripLeft("0").to!int();
	return ret;
}

Date fromWord(string s) {
	if(s.length < 3) {
		return Date.init;
	}

	Date now = cast(Date)Clock.currTime();
	const pre = s[0 .. 3].toLower();
	DayOfWeek dow;
	try {
		dow = pre.to!DayOfWeek();
	} catch(Exception e) {
		writefln("%s", pre);
		return Date.init;
	}

	const int diff = now.dayOfWeek - dow;

	auto ret = now - dur!"days"(diff);
	writefln("%s - %s = %s", now.toISOExtString(), dow, ret.toISOExtString());
	return ret;
}
