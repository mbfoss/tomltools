---@diagnostic disable: undefined-global, undefined-field, need-check-nil
-- Unit tests for the snippet encoders (lua/tomltools/encoder.lua). Whole-document
-- encoding is covered by the toml-test conformance suite; these specs pin the
-- layout of the fragment helpers, whose output is inserted into existing
-- documents and so has to carry its own indentation.

local encoder    = require("tomltools.encoder")
local table_util = require("tomltools.table_util")

describe("encode_array", function()
    it("encodes an empty array", function()
        assert.equals("[]", encoder.encode_array({}))
        assert.equals("[]", encoder.encode_array({}, { multiline = true }))
    end)

    it("keeps a short array on one line by default", function()
        assert.equals('[ 1, 2, 3 ]', encoder.encode_array({ 1, 2, 3 }))
        assert.equals('[ "a", "b" ]', encoder.encode_array({ "a", "b" }))
    end)

    it("wraps an array wider than 80 columns by default", function()
        local long = {}
        for i = 1, 10 do long[i] = ("item-%02d-padding"):format(i) end
        local out = encoder.encode_array(long)
        assert.equals('[\n  "item-01-padding",', out:sub(1, #'[\n  "item-01-padding",'))
        assert.equals('  "item-10-padding",\n]', out:sub(- #'  "item-10-padding",\n]'))
    end)

    it("switches to the wrapped form just past 80 columns", function()
        -- 35 padding characters plus both quotes encode to 37 columns, so two
        -- items land exactly on the 80-column limit: 2 + 37 + 2 + 37 + 2.
        local pad = string.rep("a", 35)
        local at_limit = encoder.encode_array({ pad, pad })
        assert.equals(80, #at_limit)
        assert.is_nil(at_limit:find("\n", 1, true))

        local over_limit = encoder.encode_array({ pad .. "a", pad .. "a" })
        assert.is_not_nil(over_limit:find("\n", 1, true))
    end)

    it("forces one item per line with multiline = true", function()
        assert.equals("[\n  1,\n  2,\n]", encoder.encode_array({ 1, 2 }, { multiline = true }))
    end)

    it("indents every line of a multiline array", function()
        assert.equals("    [\n      1,\n      2,\n    ]",
            encoder.encode_array({ 1, 2 }, { multiline = true, indent = "    " }))
    end)

    it("forces a single line with multiline = false", function()
        local long = {}
        for i = 1, 10 do long[i] = ("item-%02d-padding"):format(i) end
        local out = encoder.encode_array(long, { multiline = false })
        assert.is_nil(out:find("\n", 1, true))
        assert.equals("[ ", out:sub(1, 2))
    end)

    it("encodes nested values through the shared value encoder", function()
        assert.equals('[ [ 1, 2 ], { a = 1 }, true ]',
            encoder.encode_array({ { 1, 2 }, table_util.ordered({ a = 1 }, { "a" }), true }))
    end)
end)

describe("encode_inline", function()
    it("encodes an empty table", function()
        assert.equals("{}", encoder.encode_inline({}))
    end)

    it("keeps key order when the table carries one", function()
        local t = table_util.ordered({ b = 2, a = 1 }, { "b", "a" })
        assert.equals("{ b = 2, a = 1 }", encoder.encode_inline(t))
    end)

    it("indents every line of a multiline table", function()
        local t = table_util.ordered({ a = 1, b = 2 }, { "a", "b" })
        assert.equals("  {\n    a = 1,\n    b = 2,\n  }",
            encoder.encode_inline(t, { multiline = true, indent = "  " }))
    end)
end)

describe("encode_kvp", function()
    it("encodes one pair", function()
        assert.equals('command = "make"', encoder.encode_kvp("command", "make"))
        assert.equals("jobs = 4", encoder.encode_kvp("jobs", 4))
    end)

    it("quotes a key that is not bare", function()
        assert.equals('"my key" = 1', encoder.encode_kvp("my key", 1))
        assert.equals('"a.b" = 1', encoder.encode_kvp("a.b", 1))
    end)

    it("encodes a table value inline", function()
        assert.equals("opts = { a = 1 }", encoder.encode_kvp("opts", table_util.ordered({ a = 1 }, { "a" })))
        assert.equals("args = [ 1, 2 ]", encoder.encode_kvp("args", { 1, 2 }))
    end)
end)

describe("encode_kvps", function()
    it("returns no lines for an empty table", function()
        assert.same({}, encoder.encode_kvps({}))
    end)

    it("keeps key order when the table carries one", function()
        local t = table_util.ordered({ b = 2, a = 1 }, { "b", "a" })
        assert.same({ "b = 2", "a = 1" }, encoder.encode_kvps(t))
    end)

    it("sorts keys when the table carries no order", function()
        assert.same({ "a = 1", "b = 2" }, encoder.encode_kvps({ b = 2, a = 1 }))
    end)

    it("keeps a sub-table inline instead of promoting it to a header", function()
        local t = table_util.ordered({ env = table_util.ordered({ A = "1" }, { "A" }), jobs = 4 },
            { "env", "jobs" })
        assert.same({ 'env = { A = "1" }', "jobs = 4" }, encoder.encode_kvps(t))
    end)
end)

describe("encode_header", function()
    it("joins the segments with dots", function()
        assert.equals("[tasks.build]", encoder.encode_header({ "tasks", "build" }))
    end)

    it("quotes each segment independently", function()
        assert.equals('[tasks."my task".env]', encoder.encode_header({ "tasks", "my task", "env" }))
    end)

    it("encodes a single segment", function()
        assert.equals("[tasks]", encoder.encode_header({ "tasks" }))
    end)
end)

describe("encode_table_entry", function()
    it("quotes each segment of a dotted header independently", function()
        assert.equals('[tasks."my task"]\ntype = "shell"',
            encoder.encode_table_entry({ "tasks", "my task" }, { type = "shell" }))
    end)

    it("emits a bare header for an empty table", function()
        assert.equals("[tasks.build]", encoder.encode_table_entry({ "tasks", "build" }, {}))
    end)
end)
