module github;

import std.array;
import std.algorithm.searching : all;
import std.ascii : isASCII;
import std.typecons : Nullable, nullable;
import std.range : chain;
import std.format;
import std.json;
import std.stdio;
import std.conv : to;

import requests;

import gitauthors;
import json;

struct GithubRestResult {
	Nullable!long total_count;
	Nullable!bool incomplete_results;
	Nullable!(GithubRestPerson[]) items;
}

struct GithubRestPerson {
	string login;
}

GithubRestResult getByEmail(string email) {
	string url = "https://api.github.com/search/users?q=%s";
	email = email.replace(" ", "+");
	string withId = format(url, email);
	auto content = getContent(withId).to!string();
	writefln("%s\n%s", email, content);
	auto parsed = content.parseJSON();
	return tFromJson!GithubRestResult(parsed);
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
		if(!r.items.isNull() 
				&& r.items.get().length == 1 
				&& !r.items.get()[0].login.empty) 
		{
			ret.githubUserName = nullable(r.items.get()[0].login);
			break;
		}
	}
	return ret;
}
