module github;

import std.algorithm.iteration : filter, map;
import std.algorithm.searching : all, startsWith;
import std.array;
import std.ascii : isASCII;
import std.conv : to;
import std.format;
import std.json;
import std.file;
import std.string;
import std.range : chain;
import std.stdio;
import std.typecons : Nullable, nullable;

import requests;

import core.thread;
import core.time;

import gitauthors;
import json;
import cliargs;

struct GithubRestResult {
	Nullable!long total_count;
	Nullable!bool incomplete_results;
	Nullable!(GithubRestPerson[]) items;

	JSONValue toJSON() const {
		JSONValue ret = JSONValue(
			[ "total_count": this.total_count.isNull 
				? JSONValue(null)
				: JSONValue(this.total_count.get())
			, "incomplete_results": this.incomplete_results.isNull 
				? JSONValue(null)
				: JSONValue(this.incomplete_results.get())
			, "items": this.items.isNull 
				? JSONValue(null)
				: JSONValue(this.items.get().map!(it => it.toJSON()).array)
			]);
		return ret;
	}
}

struct GithubRestPerson {
	string login;

	JSONValue toJSON() const {
		JSONValue ret = JSONValue([ "login": this.login]);
		return ret;
	}
}

GithubRestResult getByEmail(string email) {
	string url = "https://api.github.com/search/users?q=%s";
	email = email.replace(" ", "+");
	string withId = format(url, email);
	foreach(_; 0 .. 2) {
		try {
			auto r = Request();
			r.authenticator = new BasicAuthentication(theArgs().githubUsername
					, theArgs().githubToken);
			auto content = r.get(withId);

			writefln("%s\n%s", email, content.responseBody.to!string());
			JSONValue parsed = content.responseBody.to!string().parseJSON();
			if("message" in parsed && parsed["message"].type() == JSONType.string
					&& parsed["message"].get!string()
					.indexOf("API rate limit exceeded") != -1)
			{
				writeln("API limit execeeded need to sleep");
				Thread.sleep( dur!("minutes")(1));
				writeln("Sleeping done");
				continue;
			}
			return tFromJson!GithubRestResult(parsed);
		} catch(Exception e) {
			return GithubRestResult.init;
		}
	}
	return GithubRestResult.init;
}

struct GithubPerson {
	UnifiedGitPerson gitAuthors;
	Nullable!string githubUserName; // etc. @burner
}

GithubPerson buildGithubPerson(UnifiedGitPerson ugp) {
	GithubPerson ret;
	ret.gitAuthors = ugp;
	foreach(it; chain(ugp.emails, ugp.names)
			.filter!(it => it.all!(isASCII))
			) 
	{
		GithubRestResult r = getByEmail(it);
		if(!r.items.isNull()) {
			if(r.items.get().length == 1 && !r.items.get()[0].login.empty) {
				ret.githubUserName = nullable(r.items.get()[0].login);
				break;
			} else if(r.items.get().length > 1) {
				JSONValue g = JSONValue(["search": ugp.toJSON()]);
				g["found"] = r.toJSON();
				if(exists("many_matches.json")) {
					JSONValue[] v = parseJSON(readText("many_matches.json")).arrayNoRef;
					v ~= g;
					auto f = File("many_matches.json", "w");
					f.writeln(JSONValue(v).toPrettyString());
				} else {
					auto f = File("many_matches.json", "w");
					f.writeln(JSONValue([g]));
				}
				break;
			}
		}
	}
	return ret;
}
