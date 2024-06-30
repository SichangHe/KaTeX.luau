-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/katex.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local console = LuauPolyfill.console
local instanceof = LuauPolyfill.instanceof
local exports = {}
-- @flow
--[[ eslint no-console:0 ]]
--[[*
 * This is the main entry point for KaTeX. Here, we expose functions for
 * rendering expressions either to DOM nodes or to markup strings.
 *
 * We also expose the ParseError class to check if errors thrown from KaTeX are
 * errors in the expression, or errors in javascript handling.
 ]]
local ParseError = require(script.Parent.src.ParseError).default
local settingsModule = require(script.Parent.src.Settings)
local Settings = settingsModule.default
local SETTINGS_SCHEMA = settingsModule.SETTINGS_SCHEMA
local buildTreeModule = require(script.Parent.src.buildTree)
local buildTree = buildTreeModule.buildTree
local buildHTMLTree = buildTreeModule.buildHTMLTree
local parseTree = require(script.Parent.src.parseTree).default
local buildCommon = require(script.Parent.src.buildCommon).default
local domTreeModule = require(script.Parent.src.domTree)
local Span = domTreeModule.Span
local Anchor = domTreeModule.Anchor
local SymbolNode = domTreeModule.SymbolNode
local SvgNode = domTreeModule.SvgNode
local PathNode = domTreeModule.PathNode
local LineNode = domTreeModule.LineNode
local settingsModule = require(script.Parent.src.Settings)
type SettingsOptions = settingsModule.SettingsOptions
local parseNodeModule = require(script.Parent.src.parseNode)
type AnyParseNode = parseNodeModule.AnyParseNode
local domTreeModule = require(script.Parent.src.domTree)
type DomSpan = domTreeModule.DomSpan
local defineSymbol = require(script.Parent.src.symbols).defineSymbol
local defineFunction = require(script.Parent.src.defineFunction).default
local defineMacro = require(script.Parent.src.defineMacro).default
local setFontMetrics = require(script.Parent.src.fontMetrics).setFontMetrics
error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: DeclareVariable ]] --[[ declare var __VERSION__: string; ]]
--[[*
 * Parse and build an expression, and place that expression in the DOM node
 * given.
 ]]
local render: (string, Node, SettingsOptions) -> ()
function render(expression: string, baseNode: Node, options: SettingsOptions)
	baseNode.textContent = ""
	local node = renderToDomTree(expression, options):toNode()
	baseNode:appendChild(node)
end -- KaTeX's styles don't work properly in quirks mode. Print out an error, and
-- disable rendering.
if typeof(document) ~= "undefined" then
	if document.compatMode ~= "CSS1Compat" then
		if typeof(console) ~= "undefined" then
			console.warn(
				"Warning: KaTeX doesn't work in quirks mode. Make sure your "
					.. "website has a suitable doctype."
			)
		end
		render = function()
			error(ParseError.new("KaTeX doesn't work in quirks mode."))
		end
	end
end
--[[*
 * Parse and build an expression, and return the markup for that.
 ]]
local function renderToString(expression: string, options: SettingsOptions): string
	local markup = renderToDomTree(expression, options):toMarkup()
	return markup
end
--[[*
 * Parse an expression and return the parse tree.
 ]]
local function generateParseTree(
	expression: string,
	options: SettingsOptions
): any --[[ ROBLOX TODO: Unhandled node for type: ArrayTypeAnnotation ]] --[[ AnyParseNode[] ]]
	local settings_ = Settings.new(options)
	return parseTree(expression, settings_)
end
--[[*
 * If the given error is a KaTeX ParseError and options.throwOnError is false,
 * renders the invalid LaTeX as a span with hover title giving the KaTeX
 * error message.  Otherwise, simply throws the error.
 ]]
local function renderError(error_, expression: string, options: Settings)
	if
		Boolean.toJSBoolean(
			Boolean.toJSBoolean(options.throwOnError) and options.throwOnError
				or not instanceof(error_, ParseError)
		)
	then
		error(error_)
	end
	local node = buildCommon:makeSpan({ "katex-error" }, { SymbolNode.new(expression) })
	node:setAttribute("title", tostring(error_))
	node:setAttribute("style", ("color:%s"):format(tostring(options.errorColor)))
	return node
end
--[[*
 * Generates and returns the katex build tree. This is used for advanced
 * use cases (like rendering to custom output).
 ]]
local function renderToDomTree(expression: string, options: SettingsOptions): DomSpan
	local settings_ = Settings.new(options)
	do --[[ ROBLOX COMMENT: try-catch block conversion ]]
		local ok, result, hasReturned = xpcall(function()
			local tree = parseTree(expression, settings_)
			return buildTree(tree, expression, settings_), true
		end, function(error_)
			return renderError(error_, expression, settings_), true
		end)
		if hasReturned then
			return result
		end
	end
end
--[[*
 * Generates and returns the katex build tree, with just HTML (no MathML).
 * This is used for advanced use cases (like rendering to custom output).
 ]]
local function renderToHTMLTree(expression: string, options: SettingsOptions): DomSpan
	local settings_ = Settings.new(options)
	do --[[ ROBLOX COMMENT: try-catch block conversion ]]
		local ok, result, hasReturned = xpcall(function()
			local tree = parseTree(expression, settings_)
			return buildHTMLTree(tree, expression, settings_), true
		end, function(error_)
			return renderError(error_, expression, settings_), true
		end)
		if hasReturned then
			return result
		end
	end
end
exports.default = {
	--[[*
   * Current KaTeX version
   ]]
	version = __VERSION__,
	--[[*
   * Renders the given LaTeX into an HTML+MathML combination, and adds
   * it as a child to the specified DOM node.
   ]]
	render = render,
	--[[*
   * Renders the given LaTeX into an HTML+MathML combination string,
   * for sending to the client.
   ]]
	renderToString = renderToString,
	--[[*
   * KaTeX error, usually during parsing.
   ]]
	ParseError = ParseError,
	--[[*
   * The shema of Settings
   ]]
	SETTINGS_SCHEMA = SETTINGS_SCHEMA,
	--[[*
   * Parses the given LaTeX into KaTeX's internal parse tree structure,
   * without rendering to HTML or MathML.
   *
   * NOTE: This method is not currently recommended for public use.
   * The internal tree representation is unstable and is very likely
   * to change. Use at your own risk.
   ]]
	__parse = generateParseTree,
	--[[*
   * Renders the given LaTeX into an HTML+MathML internal DOM tree
   * representation, without flattening that representation to a string.
   *
   * NOTE: This method is not currently recommended for public use.
   * The internal tree representation is unstable and is very likely
   * to change. Use at your own risk.
   ]]
	__renderToDomTree = renderToDomTree,
	--[[*
   * Renders the given LaTeX into an HTML internal DOM tree representation,
   * without MathML and without flattening that representation to a string.
   *
   * NOTE: This method is not currently recommended for public use.
   * The internal tree representation is unstable and is very likely
   * to change. Use at your own risk.
   ]]
	__renderToHTMLTree = renderToHTMLTree,
	--[[*
   * extends internal font metrics object with a new object
   * each key in the new object represents a font name
  ]]
	__setFontMetrics = setFontMetrics,
	--[[*
   * adds a new symbol to builtin symbols table
   ]]
	__defineSymbol = defineSymbol,
	--[[*
   * adds a new function to builtin function list,
   * which directly produce parse tree elements
   * and have their own html/mathml builders
   ]]
	__defineFunction = defineFunction,
	--[[*
   * adds a new macro to builtin macro list
   ]]
	__defineMacro = defineMacro,
	--[[*
   * Expose the dom tree node types, which can be useful for type checking nodes.
   *
   * NOTE: This method is not currently recommended for public use.
   * The internal tree representation is unstable and is very likely
   * to change. Use at your own risk.
   ]]
	__domTree = {
		Span = Span,
		Anchor = Anchor,
		SymbolNode = SymbolNode,
		SvgNode = SvgNode,
		PathNode = PathNode,
		LineNode = LineNode,
	},
}
return exports
