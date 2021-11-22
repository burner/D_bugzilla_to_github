module gitauthors;

import std.array;
import std.file : readText;
import std.format : format;
import std.algorithm.sorting;
import std.algorithm.searching : canFind;
import std.algorithm.comparison : cmp, equal;
import std.algorithm.iteration : map, uniq, joiner, filter;
import std.algorithm.sorting : sort;
import std.typecons : Nullable, nullable;
import std.net.isemail;
import std.uni : toLower;
import std.json;

import json;
import rest;

private struct GitPerson {
	string authorName;
	string authorEmail;

	int opCmp(GitPerson other) const pure @safe {
		return cmp([this.authorName, this.authorEmail], [other.authorName, other.authorEmail]);
	}
}

private GitPerson[] parseFile(string file) {
	return readText(file)
		.parseJSON()
		.tFromJson!(GitPerson[])();
}

private GitPerson[] parseAll() {
	return ["repos/dmd.json", "repos/phobos.json", "repos/druntime.json"]
		.map!(f => parseFile(f))
		.joiner
		.filter!(it => !canFind(it.authorEmail, "noreply.github.com"))
		.filter!(it => isEmail(it.authorEmail).valid())
		.map!(p => GitPerson(p.authorName, p.authorEmail.toLower()))
		.array
		.sort
		.uniq!((a,b) => equal([a.authorName, a.authorEmail], [b.authorName, b.authorEmail]))
		.array;
}

class UnifiedGitPerson {
	string[] names;
	string[] emails;
	Nullable!string githubUsername;
	Person bugzillaPerson;

	override string toString() const {
		return format("GitPerson(names: %(%s, %); email: %(%s, %))", this.names, this.emails);
	}

	JSONValue toJSON() const {
		JSONValue ret = JSONValue(["names": this.names, "emails": this.emails]);
		ret["bugzillaPerson"] = this.bugzillaPerson.toJSON();
		ret["githubUsername"] = this.githubUsername.isNull()
			? JSONValue(null)
			: JSONValue(this.githubUsername.get());
		return ret;
	}
}

struct Unifier {
	UnifiedGitPerson[string] byEmail;
	UnifiedGitPerson[string] byName;

	UnifiedGitPerson[] getUniq() {
		return this.byEmail.values()
			.array
			.sort!((a, b) => (&a) < (&b))
			.uniq
			.array;
	}

	void update(UnifiedGitPerson p) {
		foreach(n; p.names) {
			this.byName[n] = p;
		}
		foreach(n; p.emails) {
			this.byEmail[n] = p;
		}
	}

	void insert(GitPerson ip) {
		UnifiedGitPerson* e = ip.authorEmail in this.byEmail;
		UnifiedGitPerson* n = ip.authorName in this.byName;

		if(e !is null && n !is null) {
			auto up = new UnifiedGitPerson();
			up.names = (e.names ~ n.names ~ ip.authorName).sort.uniq.array;
			up.emails = (e.emails ~ n.emails ~ ip.authorEmail).sort.uniq.array;
			this.update(up);
		} else if(e is null && n !is null) {
			auto up = new UnifiedGitPerson();
			up.names = (n.names ~ ip.authorName).sort.uniq.array;
			up.emails = (n.emails ~ ip.authorEmail).sort.uniq.array;
			this.update(up);
		} else if(e !is null && n is null) {
			auto up = new UnifiedGitPerson();
			up.names = (e.names ~ ip.authorName).sort.uniq.array;
			up.emails = (e.emails ~ ip.authorEmail).sort.uniq.array;
			this.update(up);
		} else {
			auto up = new UnifiedGitPerson();
			up.names = [ip.authorName];
			up.emails = [ip.authorEmail];
			this.update(up);
		}
	}

	bool insert(Person p) {
		if(p.email in this.byEmail) {
			this.byEmail[p.email].bugzillaPerson = p;
			return true;
		}
		if(p.name in this.byName) {
			this.byName[p.name].bugzillaPerson = p;
			return true;
		}

		if(p.real_name in this.byName) {
			this.byName[p.real_name].bugzillaPerson = p;
			return true;
		}
		return false;
	}
	
}

private Unifier getUnifier(GitPerson[] persons) {
	Unifier unifier;
	foreach(p; persons) {
		unifier.insert(p);
	}
	return unifier;
}

private UnifiedGitPerson[] unify(GitPerson[] persons) {
	Unifier unifier;
	foreach(p; persons) {
		unifier.insert(p);
	}

	return unifier.byEmail.values();
}

private UnifiedGitPerson[] getAllGitPersons() {
	return unify(parseAll());
}

Unifier getAllGitPersonsUnifier() {
	return getUnifier(parseAll());
}
