---@diagnostic disable: undefined-global, undefined-field, need-check-nil
-- Unit tests for the CST (lua/tomltools/Cst.lua), covering the cursor lookup
-- token_at, whose two gravities disagree on a position that one node ends at
-- and another begins at.

local parser = require("tomltools.parser")
local Cst    = require("tomltools.Cst")
local K      = Cst.Kind

--- Parse lines and return the kind token_at reports at (row, col).
local function kind_at(lines, row, col, right_gravity)
    local cst = parser.parse(table.concat(lines, "\n")).cst
    return cst:kind(cst:token_at(row, col, right_gravity))
end

describe("token_at", function()
    local doc = {
        "[a]",
        'x = "1"',
        "",
        "[a.b]",
        'y = "2"',
    }

    it("finds the token containing the cursor", function()
        assert.equals(K.BareKey, kind_at(doc, 1, 0))
        assert.equals(K.String, kind_at(doc, 1, 5))
    end)

    it("keeps a cursor on a token's end boundary inside that token", function()
        -- One past the last column of "x", where completion still means "x".
        assert.equals(K.BareKey, kind_at(doc, 1, 1))
        -- The gap before the value ends where the value begins.
        assert.equals(K.Whitespace, kind_at(doc, 1, 4))
    end)

    it("resolves a section header's opening bracket to the section before it", function()
        -- [a] ends where [a.b] starts, and the boundary is claimed left first.
        assert.equals(K.TableSection, kind_at(doc, 3, 0))
        assert.equals(K.LBracket, kind_at(doc, 3, 1))
    end)

    it("gives the boundary to what starts there under right gravity", function()
        assert.equals(K.LBracket, kind_at(doc, 3, 0, true))
        assert.equals(K.String, kind_at(doc, 1, 4, true))
    end)

    it("leaves positions inside a token alone under right gravity", function()
        assert.equals(K.BareKey, kind_at(doc, 1, 0, true))
        assert.equals(K.String, kind_at(doc, 1, 5, true))
    end)

    it("always returns an id, even for an empty document", function()
        local cst = parser.parse("").cst
        assert.equals(cst:root_id(), cst:token_at(0, 0))
        assert.equals(cst:root_id(), cst:token_at(0, 0, true))
    end)
end)
