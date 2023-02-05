module allpeople;

import std.stdio;
import std.array;
import std.algorithm.iteration : filter, uniq;
import std.algorithm.sorting : sort;
import std.typecons;
import std.exception : enforce;
import std.format;
import std.file : readText;
import std.json;

import rest;
import json;

class AllPeople {
	long[] bugzillaIds;
	string githubUser;

	this(long bId, string ghu) {
		this.bugzillaIds = [bId];
		this.githubUser = ghu;
	}
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
		foreach(ref UnifiedGitPersonAll it; ap.people
				.filter!(h => !h.githubUsername.isNull())
				.filter!(h => h.bugzillaPerson.id != 0)
			) 
		{
			AllPeople* byId = it.bugzillaPerson.id in this.byBugzillaId;
			AllPeople* byGh = it.githubUsername.get() in this.byGithubId;
			if(byId is null && byGh is null) {
				auto t = new AllPeople(it.bugzillaPerson.id,
						it.githubUsername.get());
				this.byBugzillaId[it.bugzillaPerson.id] = t;
				this.byGithubId[t.githubUser] = t;
			} else if(byId is null && byGh !is null) {
				(*byGh).bugzillaIds = ((*byGh).bugzillaIds ~ it.bugzillaPerson.id).sort.uniq.array;
				foreach(id; (*byGh).bugzillaIds) {
					this.byBugzillaId[id] = *byGh;
				}
			} else if(byId !is null && byGh is null) {
				enforce((*byId).githubUser == it.githubUsername.get(), format("%s", it));
				(*byGh).bugzillaIds = ((*byGh).bugzillaIds ~ it.bugzillaPerson.id).sort.uniq.array;
				foreach(id; (*byGh).bugzillaIds) {
					this.byBugzillaId[id] = *byGh;
				}
			} else if(byId !is null && byGh !is null) {
				enforce((*byId).githubUser == it.githubUsername.get(), format("%s", it));
				enforce((*byId).githubUser == (*byGh).githubUser, format("%s", it));
				(*byGh).bugzillaIds = ((*byGh).bugzillaIds 
						~ (*byId).bugzillaIds
						~ it.bugzillaPerson.id).sort.uniq.array;
				foreach(id; (*byGh).bugzillaIds) {
					this.byBugzillaId[id] = *byGh;
				}
			}
		}
	}
}
