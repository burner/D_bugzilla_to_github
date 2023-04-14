module graphql;

import std.algorithm.iteration : map, splitter;
import std.algorithm.searching : canFind, endsWith, startsWith;
import std.array;
import std.conv;
import std.datetime;
import std.exception;
import std.file : exists, readText;
import std.format : format;
import std.json;
import std.stdio;
import std.traits : Unqual, isArray;

@safe:

JSONValue getCurrentRateLimit(string bearer) {
	string q = 
		`query {
		  viewer {
		    login
		  }
		  rateLimit {
		    limit
		    cost
		    remaining
		    resetAt
		  }
		}`;
	JSONValue limits = qlQuerySafe(q, JSONValue.init, bearer);
	return limits;
}

Label[] parseExistingLabels() {
	if(!exists("labels.json")) {
		return [];
	}
	JSONValue t = parseJSON(readText("labels.json"));
	return t.arrayNoRef()
		.map!(i => i.jsonToForgiving!Label())
		.array;
}

struct Label {
	string id;
	string color;
	string name;
}

struct LabelInput {
	string color;
	string name;
	string repositoryId;
}

Label createLabel(LabelInput input, string bearer) {
	string createLabel = `
	mutation CreateLabel($input: CreateLabelInput!) {
		createLabel(input: $input) {
			clientMutationId
			label {
				id
				color
				name
			}
		}
	}
	`;

	JSONValue vars;
	vars["name"] = input.name;
	vars["color"] = input.color;
	vars["repositoryId"] = input.repositoryId;

	JSONValue v2 = JSONValue(["input" : vars]);

	JSONValue rslt = qlMutationSafe(createLabel, v2, bearer);
	return parseHelper!Label(rslt, "data.createLabel.label");
}

struct Repository {
	string id;
}

Repository getRepository(string owner, string projectName, string bearer) {
	string repoInfo = `
	query repo($name: String!, $owner: String!) {
		repository(owner: $owner, name: $name) {
			id
		}
	}
	`;

	JSONValue vq;
	vq["name"] = projectName;
	vq["owner"] = owner;
	
	JSONValue repo = qlQuerySafe(repoInfo, vq, bearer);
	return parseHelper!Repository(repo, "data.repository");
}

struct CreateIssueInput {
	string title;
	string body_;
	string repoId;
	string[] labelIds;
}

struct CreateIssueResult {
	int number;
}

CreateIssueResult createIssue(CreateIssueInput input, string bearer) {
	const createIssue = `
	mutation CreateIssue($input: CreateIssueInput!) {
		createIssue(input: $input) {
			clientMutationId
			issue {
				number
			}
		}
	}`;

	JSONValue vars;
	vars["title"] = input.title;
	vars["body"] = input.body_;
	vars["repositoryId"] = input.repoId;
	vars["labelIds"] = input.labelIds;

	JSONValue v2 = JSONValue(["input" : vars]);
	JSONValue rslt = qlMutationSafe(createIssue, v2, bearer);
	return parseHelper!CreateIssueResult(rslt, "data.createIssue.issue");
}

private T parseHelper(T)(JSONValue input, string accessPath) {
	JSONValue toParse = getNested(input, accessPath);
	enforce(toParse.type == JSONType.object, input.toPrettyString());
	return jsonToForgiving!T(toParse);	
}

JSONValue qlRequester(string type, string request, JSONValue vars, const string bearer,
		string host) @trusted
{
	import std.format : format;
	import std.conv : to;
	import std.stdio;

	import requests;

	JSONValue ret;
	JSONValue b;
	b["query"] = request;
	b["variables"] = vars;

	Request rq = Request();
	rq.sslSetVerifyPeer(false);
	if(bearer.length > 0) {
		rq.addHeaders(
			[ "Authorization" : format("bearer %s", bearer)
			, "Accept" : "application/vnd.github.bane-preview"
			]);
	}
	string s = b.toString();
	auto rs = rq.post(host, s, "application/json");
	string t = rs.responseBody.to!string();

	try {
		ret = parseJSON(t);
	} catch(Exception e) {
		throw new Exception(format(
				"type: '%s'\nrequest: '%s'\nvars: '%s'\nret: '%s'",
				type, request, vars.toPrettyString(), t),
				__FILE__, __LINE__, e);
	}

	return ret;
}

JSONValue qlQuery(string request, string vars, const string bearer,
		string host = "https://api.github.com/graphql")
{
	return qlRequester("query", request, parseJSON(vars), bearer, host);
}

JSONValue qlMutation(string request, string vars, const string bearer,
		string host = "https://api.github.com/graphql")
{
	return qlRequester("mutation", request, parseJSON(vars), bearer, host);
}

JSONValue qlQuery(string request, JSONValue vars, const string bearer,
		string host = "https://api.github.com/graphql")
{
	return qlRequester("query", request, vars, bearer, host);
}

JSONValue qlMutation(string request, JSONValue vars, const string bearer,
		string host = "https://api.github.com/graphql")
{
	return qlRequester("mutation", request, vars, bearer, host);
}

void handleErrors(JSONValue ret, string request, JSONValue vars) {
	import std.array : replace;
	auto errors = "errors" in ret;
	if(errors !is null) {
		writeln("ERROR");
		foreach(JSONValue error; (*errors).arrayNoRef()) {
			if(error.type != JSONType.object) {
				writefln("%s %s %s", request, ret.toPrettyString()
						, vars.toPrettyString());
			}
			auto path = "path" in error;
			if(path !is null) {
				writeln((*path).toPrettyString());
			}
			auto mes = "message" in error;
			if(mes !is null) {
				string s = (*mes).get!string().replace("\\n", "\n");
				writeln(s);
			}
		}
	}
	enforce("errors" !in ret, ret.toPrettyString() ~ "\n" ~ request ~ "\n"
			~ vars.toPrettyString() ~ "\n" ~ ret["errors"].toPrettyString());
}

JSONValue qlMutationSafe(string request, string vars, const string bearer,
		string host = "https://api.github.com/graphql")
{
	JSONValue ret = qlMutation(request, vars, bearer, host);
	handleErrors(ret, request, parseJSON(vars));
	return ret;
}

JSONValue qlMutationSafe(string request, JSONValue vars, const string bearer,
		string host = "https://api.github.com/graphql")
{
	JSONValue ret = qlMutation(request, vars, bearer, host);
	handleErrors(ret, request, vars);
	return ret;
}

JSONValue qlQuerySafe(string request, string vars, const string bearer,
		string host = "https://api.github.com/graphql")
{
	JSONValue ret = qlQuery(request, vars, bearer, host);
	handleErrors(ret, request, parseJSON(vars));
	return ret;
}

JSONValue qlQuerySafe(string request, JSONValue vars, const string bearer,
		string host = "https://api.github.com/graphql")
{
	JSONValue ret = qlQuery(request, vars, bearer, host);
	handleErrors(ret, request, vars);
	return ret;
}

template directDeserialize(T) {
	import std.meta : AliasSeq, staticIndexOf;
	alias TU = Unqual!T;
	enum directDeserialize = staticIndexOf!(TU,
		bool,
		byte, short, int, long,
		ubyte, ushort, uint, ulong,
		float, double, string, char) != -1;
}

@safe DateTime getDateTime(JSONValue input) {
	enum jsDateEnd = ".000Z";
	string t = input.get!string();
	t = t.endsWith(jsDateEnd) ? t[0 .. $ - jsDateEnd.length] : t;
	return t.canFind('T')
		? DateTime.fromISOExtString(t)
		: DateTime(Date.fromISOExtString(t));
}

@safe T customDeserialize(T)(JSONValue j) {
	import std.traits : Unqual, hasUDA, getUDAs;

	static if(is(T == DateTime)) {
		return getDateTime(j);
	} else static if(is(T == Date)) {
		return getDateTime(j).date;
	} else static if(directDeserialize!T) {
		return j.get!(Unqual!(T))();
	} else static if(is(T == enum)) {
		import std.conv : to;
		return to!T(j.to!string());
	} else static if(isArray!T) {
		import std.range : ElementEncodingType;

		T ret;
		if(j.type == JSONType.array) {
			foreach(it; j.byValue) {
				ret ~= customDeserialize!(ElementEncodingType!T)(it);
			}
		}
		return ret;
	} else static if(is(T == struct)) {
		return jsonToForgiving!T(j);
	} else {
		static assert(false, "No customDeserialize for type " ~ T.stringof);
	}
}

template baseType(T) {
	static if(is(T : GQLDCustomLeaf!Fs, Fs...)) {
		alias baseType = baseType!(Fs[0]);
	} else static if(is(T : Nullable!F, F)) {
		alias baseType = baseType!F;
	} else static if(is(T : NullableStore!F, F)) {
		static assert(false,
				"We should never get here, because we don't deserialize"
				~ " NullableStore");
	} else {
		alias baseType = T;
	}
}

template canBeNull(T) {
	static if(is(T : GQLDCustomLeaf!Fs, Fs...)) {
		enum canBeNull = canBeNull!(Fs[0]);
	} else static if(is(T : Nullable!F, F)) {
		enum canBeNull = true;
	} else static if(is(T : NullableStore!F, F)) {
		static assert(false,
				"We should never get here, because we don't deserialize"
				~ " NullableStore");
	} else {
		enum canBeNull = false;
	}
}


@safe T resolveNested(T)(JSONValue input, string field) {
	static if(is(T : Nullable!F, F)) {{
		JSONValue ret;
		const bool exists = hasPathTo!JSONValue(input, field, ret);
		return exists && ret.type != JSONType.null_
			? nullable(resolveNested!F(ret, ""))
			: T.init;
	}} else {{
		JSONValue ret;
		const bool exists = hasPathTo!JSONValue(input, field, ret);
		enforce(exists, format("No field '%s' found in %s"
				, field, input.toPrettyString())
			);
		return customDeserialize!T(ret);
	}}
}

@safe T jsonToForgiving(T)(JSONValue j) {
	import std.traits : FieldNameTuple;

	T ret;
	static foreach(mem; FieldNameTuple!T) {{
		alias FieldType = typeof(__traits(getMember, T, mem));
		static if(is(FieldType : NullableStore!F, F)) {
		} else static if(is(FieldType : Nullable!F, F)) {
			JSONValue* ptr = mem in j;
			if(ptr && ptr.type == JSONType.null_) {
				__traits(getMember, ret, mem) = FieldType.init;
			} else if(ptr && ptr.type != JSONType.null_) {
				__traits(getMember, ret, mem) = nullable(extract!F(j, mem));
			}
		} else {
			const(JSONValue)* ptr = mem in j;
			if(ptr && ptr.type != JSONType.null_) {
				__traits(getMember, ret, mem) =
					resolveNested!FieldType(j, mem);
			}
		}
		
	}}
	return ret;
}

JSONValue getNested(JSONValue data, string path) {
	auto sp = path.splitter(".");
	string f;
	while(!sp.empty) {
		f = sp.front;
		sp.popFront();
		if(data.type != JSONType.object || f !in data) {
			return JSONValue(null);
		} else {
			data = data[f];
		}
	}
	return data;
}

bool hasPathTo(T)(JSONValue data, string path, ref T ret) {
	enum TT = toType!T;
	auto sp = path.splitter(".");
	string f;
	while(!sp.empty) {
		f = sp.front;
		sp.popFront();
		if(data.type != JSONType.object || f !in data) {
			return false;
		} else {
			data = data[f];
		}
	}
	static if(is(T == JSONValue)) {
		ret = data;
		return true;
	} else {
		if(data.type == TT) {
			ret = data.to!T();
			return true;
		}
		return false;
	}
}

template toType(T) {
	import std.bigint : BigInt;
	import std.traits : isArray, isIntegral, isAggregateType, isFloatingPoint,
		   isSomeString;
	static if(is(T == bool)) {
		enum toType = JSONType.bool_;
	} else static if(isIntegral!(T)) {
		enum toType = JSONType.int_;
	} else static if(isFloatingPoint!(T)) {
		enum toType = JSONType.float_;
	} else static if(isSomeString!(T)) {
		enum toType = JSONType.string;
	} else static if(isArray!(T)) {
		enum toType = JSONType.array;
	} else static if(isAggregateType!(T)) {
		enum toType = JSONType.object;
	} else static if(is(T == BigInt)) {
		enum toType = JSONType.bigint;
	} else {
		enum toType = JSONType.undefined;
	}
}
