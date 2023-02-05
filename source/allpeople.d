module allpeople;

import std.stdio;
import std.algorithm.iteration : filter;
import std.typecons;
import std.file : readText;
import std.json;

import rest;
import json;

class AllPeople {
	long[] bugzillaIds;
	string githubUser;
}

struct UnifiedGitPersonAll {
	string[] names;
	string[] emails;
	Nullable!string githubUsername;
	Person bugzillaPerson;
}

struct AllPeoples {
	UnifiedGitPersonAll[] people;
}

struct AllPeopleHandler {
	AllPeople[long] byBugzillaId;
	AllPeople[string] byGithubId;

	void load() {
		AllPeoples ap = tFromJson!AllPeoples(parseJSON(readText("all_people.json")));
		foreach(it; ap.people.filter!(h => !h.githubUsername.isNull())) {
			writeln(it);
		}
	}
}
