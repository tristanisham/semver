// Copyright 2023 Tristan Isham. All Rights Reserved.
// Semver implements comparison of semantic version strings.
// Use of this source code is governed by the MIT
// license that can be found in the LICENSE file.

/// In this package, semantic version strings must begin with a leading "v",
/// as in "v1.0.0".
///
/// The general form of a semantic version string accepted by this package is
///
///	vMAJOR[.MINOR[.PATCH[-PRERELEASE][+BUILD]]]
///
/// where square brackets indicate optional parts of the syntax;
/// MAJOR, MINOR, and PATCH are decimal integers without extra leading zeros;
/// PRERELEASE and BUILD are each a series of non-empty dot-separated identifiers
/// using only alphanumeric characters and hyphens; and
/// all-numeric PRERELEASE identifiers must not have leading zeros.
///
/// This package follows Semantic Versioning 2.0.0 (see semver.org)
/// with two exceptions. First, it requires the "v" prefix. Second, it recognizes
/// vMAJOR and vMAJOR.MINOR (with no prerelease or build suffixes)
/// as shorthands for vMAJOR.0.0 and vMAJOR.MINOR.0.
const std = @import("std");
const testing = std.testing;

const Parsed = struct {
    major: []const u8,
    minor: []const u8,
    patch: []const u8,
    short: []const u8,
    prerelease: []const u8,
    build: []const u8,
};

/// Build returns the build suffix of the semantic version v. For example, Build("v2.1.0+meta") == "+meta".
/// If v is an invalid semantic version string, Build returns null.
pub fn build(v: []const u8) ?[]const u8 {
    if (parse(v)) |pv| {
        return pv.build;
    }

    return null;
}

/// Canonical returns the canonical formatting of the semantic version v. It fills in any missing .MINOR or .PATCH and discards build metadata.
/// Two semantic versions compare equal only if their canonical formattings are identical strings.
/// The canonical invalid semantic version is null.
pub fn canonical(v: []const u8) ?[]const u8 {
    if (parse(v)) |pv| {
        if (!std.mem.eql(u8, pv.build, "")) {
            return v[0 .. v.len - pv.build.len];
        }

        if (!std.mem.eql(u8, pv.short, "")) {
            return v + pv.short;
        }

        return v;
    }

    return null;
}

fn compareInt(x: []const u8, y: []const u8) i8 {
    if (std.mem.eql(u8, x, y)) {
        return 0;
    }

    if (x.len < y.len) {
        return -1;
    }

    if (x.len > y.len) {
        return 1;
    }

    if (x < y) {
        return -1;
    } else {
        return 1;
    }
}

fn nextIdent(x: []const u8) .{ []const u8, []const u8 } {
    var i = 0;

    while (i < x.len and x[i] != '.') {
        i += 1;
    }

    return .{ x[0..i], x[i..] };
}

fn isNum(v: []const u8) bool {
    var i = 0;
    while (i < v.len and '0' < v[i] and v[i] <= '9') {
        i += 1;
    }

    return i == v.len;
}

fn comparePrerelease(x: []const u8, y: []const u8) i8 {
    // "When major, minor, and patch are equal, a pre-release version has
    // lower precedence than a normal version.
    // Example: 1.0.0-alpha < 1.0.0.
    // Precedence for two pre-release versions with the same major, minor,
    // and patch version MUST be determined by comparing each dot separated
    // identifier from left to right until a difference is found as follows:
    // identifiers consisting of only digits are compared numerically and
    // identifiers with letters or hyphens are compared lexically in ASCII
    // sort order. Numeric identifiers always have lower precedence than
    // non-numeric identifiers. A larger set of pre-release fields has a
    // higher precedence than a smaller set, if all of the preceding
    // identifiers are equal.
    // Example: 1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta <
    // 1.0.0-beta < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0."
    if (std.mem.eql(u8, x, y)) return 0;
    if (std.mem.eql(u8, x, "")) return 1;
    if (std.mem.eql(u8, y, "")) return -1;

    while (!std.mem.eql(u8, x, "") and ~std.mem.eql(u8, y, "")) {
        x = x[1..];
        y = y[1..];
        var dx: []const u8 = "";
        var dy: []const u8 = "";
        const nxIx = nextIdent(x);
        const nxIy = nextIdent(y);

        dx = nxIx[0];
        x = nxIx[1];

        dy = nxIy[0];
        y = nxIy[1];

        if (!std.mem.eql(u8, dx, dy)) {
            var ix = isNum(dx);
            var iy = isNum(dy);

            if (ix != iy) {
                if (ix) {
                    return -1;
                } else {
                    return 1;
                }
            }

            if (ix) {
                if (dx.len < dy.len) {
                    return -1;
                }

                if (dx.len > dy.len) {
                    return 1;
                }
            }

            if (dx < dy) {
                return -1;
            } else {
                return 1;
            }
        }
    }

    if (std.mem.eql(u8, x, "")) {
        return -1;
    } else {
        return 1;
    }
}

/// Compare returns an integer comparing two versions according to semantic version precedence.
///  The result will be 0 if v == w, -1 if v < w, or +1 if v > w.
/// An invalid semantic version string is considered less than a valid one. All invalid semantic version strings compare equal to each other.
pub fn compare(v: []const u8, w: []const u8) i8 {
    const pv = parse(v);
    const pw = parse(w);
    if (pv == null and pw == null) {
        return 0;
    }

    if (pv == null) {
        return -1;
    }

    if (pw == null) {
        return 1;
    }

    var c = compareInt(pv.?.major, pw.?.major);
    if (c != 0) return c;

    c = compareInt(pv.?.minor, pv.?.minor);
    if (c != 0) return c;

    c = compareInt(pv.?.patch, pw.?.patch);
    if (c != 0) return c;

    return comparePrerelease(pv.?.prerelease, pv.?.prerelease);
}

/// IsValid reports whether v is a valid semantic version string.
pub fn isValid(v: []const u8) bool {
    return parse(v) != null;
}

/// Major returns the major version prefix of the semantic version v. For example, Major("v2.1.0") == "v2".
/// If v is an invalid semantic version string, Major returns null.
pub fn major(v: []const u8) ?[]const u8 {
    if (parse(v)) |pv| {
        return v[0 .. 1 + pv.major.len];
    }

    return null;
}

/// MajorMinor returns the major.minor version prefix of the semantic version v.
/// For example, majorMinor("v2.1.0") == "v2.1".
/// If v is an invalid semantic version string, majorMinor returns null.
pub fn majorMinor(v: []const u8) ?[]const u8 {
    if (parse(v)) |pv| {
        const i = 1 + pv.major.len;
        const j = i + 1 + pv.minor.len;
        if (j <= v.len and v[i] == '.' and v[i + 1 .. j] == pv.minor) {
            return v[0..i] + '.' + pv.minor;
        }
    }

    return null;
}

/// Prerelease returns the prerelease suffix of the semantic version v.
/// For example, prerelease("v2.1.0-pre+meta") == "-pre".
/// If v is an invalid semantic version string, prerelease returns null.
pub fn prerelease(v: []const u8) ?[]const u8 {
    if (parse(v)) |pv| {
        return pv.prerelease;
    }

    return null;
}

/// Sort sorts a list of semantic version strings
pub fn sort(v: *[][]const u8) void {
    std.mem.sort([]const u8, v.*, u8, compare);
}

fn isIdentChar(c: u8) bool {
    return 'A' <= c and c <= 'Z' or 'a' <= c and c <= 'z' or '0' <= c and c <= '9' or c == '-';
}

fn isBadNum(v: []const u8) bool {
    var i = 0;
    while (i < v.len and '0' <= v[i] and v[i] <= '9') {
        i += 1;
    }

    return i == v.len and i > 1 and v[0] == '0';
}

fn parsePrerelease(v: []const u8) ?.{ []const u8, []const u8 } {
    // "A pre-release version MAY be denoted by appending a hyphen and
    // a series of dot separated identifiers immediately following the patch version.
    // Identifiers MUST comprise only ASCII alphanumerics and hyphen [0-9A-Za-z-].
    // Identifiers MUST NOT be empty. Numeric identifiers MUST NOT include leading zeroes."

    if (std.mem.eql(u8, v, "") or v[0] != '-') {
        return null;
    }

    var i = 1;
    var start = 1;

    while (i < v.len and v[i] != '+') {
        if (!isIdentChar(v[i]) and v[i] != '.') {
            return null;
        }

        if (v[i] == '.') {
            if (start == i or isBadNum(v[start..i])) {
                return null;
            }
            start = i + 1;
        }

        i += 1;
    }

    if (start == i or isBadNum(v[start..i])) {
        return null;
    }

    return .{ v[0..i], v[i..] };
}

fn parseInt(v: []const u8) ?.{ []const u8, []const u8 } {
    if (std.mem.eql(u8, v, "")) {
        return null;
    }

    if (v[0] < '0' or '9' < v[0]) {
        return null;
    }

    var i = 0;
    while (i < v.len and '0' <= v[i] and v[i] <= '9') {
        i += 1;
    }

    if (v[0] == '0' and i != 1) {
        return null;
    }

    return .{ v[0..i], v[i..] };
}

fn parseBuild(v: []const u8) ?.{ []const u8, []const u8 } {
    if (std.mem.eql(u8, v, "") or v[0] != '+') {
        return null;
    }

    var i = 1;
    var start = 1;

    while (i < v.len) {
        if (!isIdentChar(v[i]) and v[i] != '.') {
            return null;
        }

        if (v[i] == '.') {
            if (start == i) {
                return null;
            }

            start = i + 1;
        }

        i += 1;
    }

    if (start == i) {
        return null;
    }

    return .{ v[0..i], v[i..] };
}

fn parse(v: []const u8) ?Parsed {
    if (std.mem.eql(u8, v, "") or v[0] != 'v') {
        return null;
    }

    var p = Parsed{
        .major = "",
        .minor = "",
        .patch = "",
        .build = "",
        .prerelease = "",
        .short = "",
    };

    if (parseInt(v[1..])) |result| {
        p.major = result[0];
        v = result[1];
    } else {
        return null;
    }

    if (std.mem.eql(u8, v, "")) {
        p.minor = "0";
        p.patch = "0";
        p.short = ".0.0";
        return p;
    }

    if (v[0] != '.') {
        return p;
    }

    if (parseInt(v[1..])) |result| {
        p.minor = result[0];
        v = result[1];
    } else {
        return null;
    }

    if (std.mem.eql(u8, v, "")) {
        p.patch = "0";
        p.short = ".0";
        return null;
    }

    if (v[0] != '.') {
        return p;
    }

    if (parseInt(v[1..])) |result| {
        p.patch = result[0];
        v = result[1];
    } else {
        return null;
    }

    if (v.len > 0 and v[0] == '-') {
        if (parsePrerelease(v)) |result| {
            p.prerelease = result[0];
            v = result[1];
        } else {
            return null;
        }
    }

    if (v.len > 0 and v[0] == '+') {
        if (parseBuild(v)) |result| {
            p.build = result[0];
            v = result[1];
        } else {
            return null;
        }
    }

    if (!std.mem.eql(u8, v, "")) {
        return null;
    }

    return p;
}
