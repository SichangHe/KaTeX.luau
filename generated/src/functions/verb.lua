-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/verb.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local RegExp = require(Packages.RegExp)
-- @flow
local defineFunction = require(script.Parent.Parent.defineFunction).default
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local ParseError = require(script.Parent.Parent.ParseError).default
local parseNodeModule = require(script.Parent.Parent.parseNode)
type ParseNode = parseNodeModule.ParseNode
defineFunction({
	type = "verb",
	names = { "\\verb" },
	props = { numArgs = 0, allowedInText = true },
	handler = function(self, context, args, optArgs)
		-- \verb and \verb* are dealt with directly in Parser.js.
		-- If we end up here, it's because of a failure to match the two delimiters
		-- in the regex in Lexer.js.  LaTeX raises the following error when \verb is
		-- terminated by end of line (or file).
		error(ParseError.new("\\verb ended by end of line instead of matching delimiter"))
	end,
	htmlBuilder = function(self, group, options)
		local text = makeVerb(group)
		local body = {} -- \verb enters text mode and therefore is sized like \textstyle
		local newOptions = options:havingStyle(options.style:text())
		do
			local i = 0
			while
				i
				< text.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			do
				local c = text[tostring(i)]
				if c == "~" then
					c = "\\textasciitilde"
				end
				table.insert(
					body,
					buildCommon:makeSymbol(
						c,
						"Typewriter-Regular",
						group.mode,
						newOptions,
						{ "mord", "texttt" }
					)
				) --[[ ROBLOX CHECK: check if 'body' is an Array ]]
				i += 1
			end
		end
		return buildCommon:makeSpan(
			Array.concat({ "mord", "text" }, newOptions:sizingClasses(options)),
			buildCommon:tryCombineChars(body),
			newOptions
		)
	end,
	mathmlBuilder = function(self, group, options)
		local text = mathMLTree.TextNode.new(makeVerb(group))
		local node = mathMLTree.MathNode.new("mtext", { text })
		node:setAttribute("mathvariant", "monospace")
		return node
	end,
})
--[[*
 * Converts verb group into body string.
 *
 * \verb* replaces each space with an open box \u2423
 * \verb replaces each space with a no-break space \xA0
 ]]
local function makeVerb(group: ParseNode<"verb">): string
	return group.body:replace(
		RegExp(" ", "g"), --[[ ROBLOX NOTE: global flag is not implemented yet ]]
		if Boolean.toJSBoolean(group.star) then "\u{2423}" else "\xA0"
	)
end
