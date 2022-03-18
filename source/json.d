module json;

import std.array;
import std.json;
import std.datetime.systime;
import std.exception : enforce;
import std.algorithm.iteration : map;
import std.typecons;
import std.string : stripRight;
import std.format;
import std.range : ElementEncodingType;
import std.traits;
import std.stdio;

import rest;

T tFromJson(T)(JSONValue js) {
	//writeln(js.toPrettyString());
	T ret;
	static if(isArray!T && !isSomeString!T) {{
		if(js.type() == JSONType.array) {
			ret ~= js.arrayNoRef()
				.map!(it => tFromJson!(ElementEncodingType!T)(it))
				.array;
		}
	}} else static if(is(T == struct)) {{
		enforce(js.type() == JSONType.object
				, format("%s %s", js.type(), js.toPrettyString())
			);
		JSONValue[string] obj = js.objectNoRef();
		static foreach(memPre; FieldNameTuple!(T)) {{
			enum mem = memPre.stripRight("_");
			//writefln("   %s %s", mem, js.toPrettyString());
			alias MT = typeof(__traits(getMember, T, memPre));
			static if(is(MT : Nullable!F, F)) {{
				if(mem in obj && obj[mem].type != JSONType.null_) {
					static if(is(F == SysTime)) {{
						__traits(getMember, ret, memPre) = SysTime.fromISOExtString(obj[mem].get!string());
					}} else static if(is(F == struct)) {{
						__traits(getMember, ret, memPre) = tFromJson!F(obj[mem]);
					}} else static if(isArray!F && !isSomeString!F) {{
						__traits(getMember, ret, memPre) = tFromJson!F(obj[mem]);
					}} else {{
						__traits(getMember, ret, memPre) = obj[mem].get!F();
					}}
				} else {
					__traits(getMember, ret, memPre) = MT.init;
				}
			}} else static if(is(MT == SysTime)) {{
				//writefln("%s %s", mem, obj.keys().sort);
				__traits(getMember, ret, memPre) = SysTime.fromISOExtString(obj[mem].get!string());
			}} else static if(is(MT == struct)) {{
				__traits(getMember, ret, memPre) = tFromJson!MT(obj[mem]);
			}} else static if(isArray!MT && !isSomeString!MT) {{
				//writefln("%s %s", mem, obj.keys().sort);
				__traits(getMember, ret, memPre) = tFromJson!(MT)(obj[mem]);
			}} else {{
				//writefln("%s %s", MT.stringof, mem);
				//writefln("%s %s", MT.stringof, obj[mem]);
				static if(is(MT == bool)) {
					if(obj[mem].type == JSONType.true_) {
						__traits(getMember, ret, memPre) = true;
					} else if(obj[mem].type == JSONType.false_) {
						__traits(getMember, ret, memPre) = false;
					} else {
						__traits(getMember, ret, memPre) = obj[mem].get!long() != 0;
					}
				} else {
					__traits(getMember, ret, memPre) = obj[mem].get!MT();
				}
			}}
		}}
	}}
	return ret;
}
