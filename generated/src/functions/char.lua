-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/char.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
-- @flow
local defineFunction = require(script.Parent.Parent.defineFunction).default
local ParseError = require(script.Parent.Parent.ParseError).default
local assertNodeType = require(script.Parent.Parent.parseNode).assertNodeType -- \@char is an internal function that takes a grouped decimal argument like
-- {123} and converts into symbol with code 123.  It is used by the *macro*
-- \char defined in macros.js.
defineFunction({
	type = "textord",
	names = { "\\@char" },
	props = { numArgs = 1, allowedInText = true },
	handler = function(self, ref0, args)
		local parser = ref0.parser
		local arg = assertNodeType(
			args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"ordgroup"
		)
		local group = arg.body
		local number = ""
		do
			local i = 0
			while
				i
				< group.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			do
				local node = assertNodeType(group[tostring(i)], "textord")
				number += node.text
				i += 1
			end
		end
		local code = tonumber(number)
		local text
		if Boolean.toJSBoolean(isNaN(code)) then
			error(ParseError.new(("\\@char has non-numeric argument %s"):format(tostring(number)))) -- If we drop IE support, the following code could be replaced with
		-- text = String.fromCodePoint(code)
		elseif
			code < 0 --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			or code >= 0x10ffff --[[ ROBLOX CHECK: operator '>=' works only if either both arguments are strings or both are a number ]]
		then
			error(ParseError.new(("\\@char with invalid code point %s"):format(tostring(number))))
		elseif
			code
			<= 0xffff --[[ ROBLOX CHECK: operator '<=' works only if either both arguments are strings or both are a number ]]
		then
			text = String:fromCharCode(code)
		else
			-- Astral code point; split into surrogate halves
			code -= 0x10000
			text = String:fromCharCode(
				bit32.arshift(code, 10) --[[ ROBLOX CHECK: `bit32.arshift` clamps arguments and result to [0,2^32 - 1] ]]
					+ 0xd800,
				bit32.band(code, 0x3ff) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
					+ 0xdc00
			)
		end
		return { type = "textord", mode = parser.mode, text = text }
	end,
})
