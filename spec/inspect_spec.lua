---@diagnostic disable: undefined-global, undefined-field, need-check-nil
-- Unit tests for cursor inspection (lua/tomltools/inspect.lua). find_path reports
-- the structural insertion context at a cursor: an array node, an AoT node, {} at
-- document root (a valid new-section point), or nil when the cursor is not at an
-- insertable position.

local inspect = require("tomltools.inspect")

--- Build a document from lines and locate the "|" cursor marker, returning the
--- text (marker stripped) plus its 0-indexed row/col. Exactly one line must
--- contain a "|".
local function at_cursor(lines)
    local row, col, found
    for i, line in ipairs(lines) do
        local c = line:find("|", 1, true)
        if c then
            assert(not found, "multiple cursor markers")
            row, col, found = i - 1, c - 1, true
            line = line:gsub("|", "", 1)
        end
        lines[i] = line
    end
    assert(found, "no cursor marker")
    return table.concat(lines, "\n"), row, col
end

--- find_path at the "|" marker in the given lines.
local function path_at(lines)
    local text, row, col = at_cursor(lines)
    return inspect.find_path(text, row, col)
end

describe("find_path", function()
    it("returns nil when parsing yields no CST", function()
        -- An unterminated string never produces a usable CST root.
        assert.is_nil(inspect.find_path('x = "', 0, 5))
    end)

    describe("document root", function()
        it("is empty before any section (leading trivia)", function()
            local p = path_at({
                "|",
                "[[tasks]]",
                'name = "a"',
            })
            assert.same({}, p)
        end)

        it("treats the trailing gap of a single top-level [table] as root", function()
            -- The cursor after a [expressions] section (before the next [[tasks]])
            -- is a valid new-section insertion point, not a dead position.
            local p = path_at({
                "[expressions]",
                'greet = "x"',
                "",
                "|",
                "[[tasks]]",
                'name = "greet"',
            })
            assert.same({}, p)
        end)
    end)

    describe("single-key [table] trailing gap", function()
        it("resolves root when the cursor lands on the section composite", function()
            -- No blank line before the marker: token_at returns the TableSection
            -- node itself rather than a trailing newline child.
            local text = table.concat({ "[expressions]", 'greet = "x"', "" }, "\n")
            local p = inspect.find_path(text, 2, 0)
            assert.same({}, p)
        end)

        it("rejects a position that precedes an existing key", function()
            -- A new [[header]] here would capture `greet` into the wrong table.
            local p = path_at({
                "[expressions]",
                "|",
                'greet = "x"',
            })
            assert.is_nil(p)
        end)

        it("is nil when the cursor is inside a key-value pair", function()
            local p = path_at({
                "[expressions]",
                'gr|eet = "x"',
            })
            assert.is_nil(p)
        end)
    end)

    describe("AoT sections", function()
        it("reports the array name in the trailing gap", function()
            local p = path_at({
                "[[tasks]]",
                'name = "a"',
                "|",
            })
            assert.same({ { name = "tasks", type = "aot" } }, p)
        end)

        it("reports the array when the cursor lands on the section composite", function()
            -- No blank line: the marker sits in the gap right after the last key,
            -- where token_at returns the AotSection node.
            local text = table.concat({ "[[tasks]]", 'name = "a"', "" }, "\n")
            local p = inspect.find_path(text, 2, 0)
            assert.same({ { name = "tasks", type = "aot" } }, p)
        end)

        it("rejects a position that precedes an existing key", function()
            local p = path_at({
                "[[tasks]]",
                "|",
                'name = "a"',
            })
            assert.is_nil(p)
        end)
    end)

    describe("dotted [a.b] table", function()
        it("binds the trailing gap to the enclosing [[a]] array", function()
            local p = path_at({
                "[tasks.debug]",
                "program = 1",
                "|",
            })
            assert.same({ { name = "tasks", type = "aot" } }, p)
        end)

        it("rejects a position that precedes an existing key", function()
            local p = path_at({
                "[tasks.debug]",
                "|",
                "program = 1",
            })
            assert.is_nil(p)
        end)
    end)

    describe("inline arrays", function()
        it("reports an array node with item indentation", function()
            local p = path_at({
                "tasks = [",
                '  { name = "a" },',
                "  |",
                "]",
            })
            assert.same({ { name = "tasks", type = "array", indent = "  " } }, p)
        end)
    end)
end)
