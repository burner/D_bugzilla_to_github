module allpeople2;

import std.array;
import std.typecons : Nullable, nullable;
import std.algorithm : all, canFind, filter, joiner, map, uniq, sort;
import std.file : exists, readText, dirEntries, SpanMode;
import std.range : chain, take;
import std.ascii : isASCII;
import std.json;
import std.stdio;
import std.net.isemail;

import rest;
import github;

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

struct AllPeople2 {
	Person bugzillaPerson;
	Nullable!string githubUserid;

	JSONValue toJSON() const {
		JSONValue ret = JSONValue(
			[ "bugzillaPerson": this.bugzillaPerson.toJSON()
			, "githubUserid": this.githubUserid.isNull 
				? JSONValue(null)
				: JSONValue(this.githubUserid.get())
			]);
		return ret;
	}
}

Nullable!string getGithubHandle(Person p) {
	foreach(it; chain([p.email].filter!(e => isEmail(e))
				, [p.real_name, p.name].filter!(n => !n.empty))
			.filter!(jt => jt.all!(isASCII)))
	{
		GithubRestResult r = getByEmail(it);
		if(!r.items.isNull()) {
			if(r.items.get().length == 1 && !r.items.get()[0].login.empty) {
				return nullable(r.items.get()[0].login);
			} else if(r.items.get().length > 1) {
				JSONValue g = JSONValue(["search": p.toJSON()]);
				g["found"] = r.toJSON();
				if(exists("many_matches2.json")) {
					JSONValue[] v = parseJSON(readText("many_matches2.json")).arrayNoRef;
					v ~= g;
					auto f = File("many_matches2.json", "w");
					f.writeln(JSONValue(v).toPrettyString());
				} else {
					auto f = File("many_matches2.json", "w");
					f.writeln(JSONValue([g]));
				}
				break;
			}
		}
	}
	return Nullable!(string).init;
}

struct AllPeopleJoined {
	import allpeople : AllPeopleHandler;

	AllPeople2[] byBugzillaIdWithGithub;

	void loadFromIssues() {
		AllPeopleHandler aph;
		aph.load();
		Bug[] bugs = allBugs();
		this.byBugzillaIdWithGithub= bugs.map!((Bug b) => b.cc_detail ~ b.creator_detail
				~ b.cc_detail ~ b.assigned_to_detail)
			.joiner
			.array
			.sort!((a, b) => a.id < b.id)
			.uniq!((a, b) => a.id == b.id)
			.map!((a) {
				auto g = a.id in aph.byBugzillaId;
				if(g !is null && !(*g).githubUser.empty) {
					return AllPeople2(a, (*g).githubUser.nullable);
				} else {
					return AllPeople2(a, getGithubHandle(a));
				}
			})
			.array;

		writeln(this.byBugzillaIdWithGithub.length);
		auto f = File("all_people2.json", "w");
		f.writeln(JSONValue([this.byBugzillaIdWithGithub.map!(it =>
						it.toJSON()).array]).toPrettyString());
	}
}
