import std.array;
import std.stdio;
import std.algorithm.iteration : filter, joiner, map, uniq;
import std.algorithm.searching : canFind;
import std.algorithm.sorting : sort;
import std.traits;
import std.json;
import std.file;
import std.format;
import std.typecons;
import std.uni : toLower;
import std.range : iota;

import core.thread;
import core.time;

import rest;
import cliargs;
import gitauthors;
import github;
import json;

Comment[] allComment() {
	return dirEntries("issues/", "bug*.json", SpanMode.depth)
			.filter!(it => canFind(it.name, "comment"))
			.map!((de) {
				string d = readText(de.name);
				return !d.empty
					? parseComment(parseJSON(d))
					: [];
			})
			.joiner
			.array;
}

Bug[] allBugs() {
	return dirEntries("issues/", "bug*.json", SpanMode.depth)
			.filter!(it => !canFind(it.name, "comment"))
			.map!((de) {
				string d = readText(de.name);
				return !d.empty
					? parseBugs(parseJSON(d))
					: [];
			})
			.joiner
			.array;
}

string[] allVersions(Bug[] b) {
	auto versions = b
		.map!(b => b.version_)
		.array
		.sort!((a,b) => a < b)
		.array
		.uniq!((a,b) => a == b)
		.array;
	return versions;
}

auto getImplSingle(string mem)(Bug[] b) {
	auto arr = b
		.map!(b => __traits(getMember, b, mem))
		.filter!((it) {
			static if(is(typeof(it) : Nullable!F, F)) {
				return !it.isNull();
			} else {
				return true;
			}
		})
		.map!((it) {
			static if(is(typeof(it) : Nullable!F, F)) {
				return it.get();
			} else {
				return it;
			}
		})
		.array
		.sort!((a,b) => a < b)
		.array
		.uniq!((a,b) => a == b)
		.array;
	return arr;
}

auto getImplMultiple(string mem)(Bug[] b) {
	auto arr = b
		.map!(b => __traits(getMember, b, mem))
		.filter!((it) {
			static if(is(typeof(it) : Nullable!F, F)) {
				return !it.isNull();
			} else {
				return true;
			}
		})
		.map!((it) {
			static if(is(typeof(it) : Nullable!F, F)) {
				return it.get();
			} else {
				return it;
			}
		})
		.joiner
		.filter!((it) {
			static if(is(typeof(it) : Nullable!F, F)) {
				return !it.isNull();
			} else {
				return true;
			}
		})
		.map!((it) {
			static if(is(typeof(it) : Nullable!F, F)) {
				return it.get();
			} else {
				return it;
			}
		})
		.array
		.sort!((a,b) => a < b)
		.array
		.uniq!((a,b) => a == b)
		.array;
	return arr;
}

auto all(string mem,T)(Bug[] b) {
	static if(isArray!T && !isSomeString!T) {{
		return getImplMultiple!mem(b);
	}} else {{
		return getImplSingle!mem(b);
	}}
}

string[] allKeywords(Bug[] b) {
	return all!("keywords",string[])(b);
}

string[] allVersion(Bug[] b) {
	return all!("version_",string)(b);
}

string[] allCC(Bug[] b) {
	return all!("cc",string[])(b);
}

Bug[long] joinBugsAndComments(Bug[] bugs, Comment[] comments) {
	Bug[long] ret = assocArray(bugs.map!(it => it.id), bugs);
	foreach(c; comments) {
		Bug* b = c.bug_id in ret;
		if(b !is null) {
			if(b.comments.isNull()) {
				b.comments = [ c ];
			} else {
				b.comments.get() ~= c;
			}
		} else {
			writefln("Bug with id is not found %s", c.bug_id);
		}
	}

	return ret;
}

Person[] buildAllPersons(Bug[] b) {
	Person[] allPersons = b
		.map!(b => b.cc_detail ~ b.assigned_to_detail ~ b.creator_detail)
		.joiner
		.filter!(it => it.email.length > 2 
				&& it.name.length > 2 
				&& it.real_name.length > 2)
		.map!(p => Person(p.id, p.email.toLower(), p.name, p.real_name))
		.array
		.sort!((a,b) => a.id < b.id)
		.array
		.uniq!((a,b) => a.id == b.id)
		.array;
	return allPersons;
}

Unifier getUnifier(Person[] allPersons) {
	Unifier uf = getAllGitPersonsUnifier();
	foreach(it; allPersons) {
		uf.insert(it);
	}

	UnifiedGitPerson[] afterGithub;
	foreach(idx, UnifiedGitPerson it; uf.getUniq()) {
		GithubPerson gh = buildGithubPerson(it);
		Thread.sleep( dur!("seconds")(8) );
		if(!gh.githubUserName.isNull()) {
			it.githubUsername = gh.githubUserName.get();
		} else {
			writefln("%(%s, %) ;; NOT FOUND", gh.gitAuthors.emails);
		}
		afterGithub ~= it;
	}
	JSONValue d = JSONValue(["people" : afterGithub.map!(i =>
				i.toJSON()).array]);
	auto f = File("all_people.json", "w");
	f.writeln(d.toPrettyString());

	return uf;
}

struct UnifiedGitPersonLoaded {
	string[] names;
	string[] emails;
	Nullable!string githubUsername;
	Person bugzillaPerson;
}

UnifiedGitPersonLoaded[] loadAllGithubPersonWithGithubUsername() {
	JSONValue sv = readText("all_people.json").parseJSON();
	return tFromJson!(UnifiedGitPersonLoaded[])(sv["people"])
		.filter!(p => p.githubUsername.isNull())
		.map!(p => UnifiedGitPersonLoaded(p.names.filter!(n => !n.empty).array
					, p.emails.filter!(e => !e.empty).array, p.githubUsername
					, p.bugzillaPerson))
		.filter!(p => !p.names.empty 
				|| !p.emails.empty
				|| p.bugzillaPerson.id != 0
				|| !p.bugzillaPerson.email.empty
				|| !p.bugzillaPerson.name.empty
				|| !p.bugzillaPerson.real_name.empty)
		.array;
}

/**
Afterwards send fixup PR's to fix issue numbers in the
dmd, druntime, phobos. Thank you WebFreak for the idea
*/

void main(string[] args) {
	if(parseOptions(args)) {
		return;
	}
	/*Bug[] b = allBugs();
	
	Comment[] c = allComment();

	Bug[long] bugsAA = joinBugsAndComments(b, c);
	*/

	writefln("%(%s\n%)", loadAllGithubPersonWithGithubUsername());

	/*
	Person[] allPersons = buildAllPersons(b);

	writefln("%(%s\n%)", allPersons);
	*/

	/*
	auto notFound = allPersons
		.filter!(p => p.email !in uf.byEmail 
				&& p.name !in uf.byName 
				&& p.real_name !in uf.byName)
		.array;
	writefln("%(%s\n%)", notFound);
	writeln(notFound.length);
	*/
}
