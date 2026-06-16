# Full Fountain Parser Implementation Plan

This document describes how to expand the initial parser implementation into a full Fountain parser while preserving the current public API shape.

## Goal

Keep the top-level contract stable:

```elixir
[
  title: title_elements,
  script: script_elements
]
```

Where:

- `title_elements` is a keyword list of title-page metadata
- `script_elements` is a list of atom-tagged tuples
- scenes remain the main structural container:

```elixir
{:scene, scene_elements}
```

## Target output model

### Title page

Recognized title-page keys should be normalized to atoms, while unknown keys are preserved:

```elixir
[title: "Example", author: "Jane Doe", credit: "Written by"]
```

Unknown keys:

```elixir
[meta: {"foo", "bar"}]
```

Preserve duplicates in input order using keyword-list semantics.

## Proposed script element shapes

### Scene

```elixir
{:scene, [
  {:heading, "INT. ROOM - DAY"},
  {:action, "A table sits in the corner."},
  {:dialogue, [character: "ALICE", parenthesis: ["(quietly)"], dialog: "We should go.", simultaneous: false]}
]}
```

### Action

```elixir
{:action, "A block of action text"}
```

Contiguous multiline action should be preserved as one block with embedded newlines.

### Dialogue

```elixir
{:dialogue,
 [
   character: "ALICE",
   parenthesis: ["(quietly)", "(beat)"],
   dialog: "We should go.\nRight now.",
   simultaneous: false
 ]}
```

### Dual-dialogue

Represent dual-dialogue using the existing `simultaneous` flag:

```elixir
{:dialogue,
 [
   character: "ALICE",
   parenthesis: [],
   dialog: "Go!",
   simultaneous: true
 ]}
```

### Lyrics

```elixir
{:lyrics, "Somewhere over the rainbow"}
```

### Transition

```elixir
{:transition, "CUT TO:"}
```

### Centered text

```elixir
{:centered, "THE END"}
```

### Page break

Normalize page breaks as:

```elixir
{:page_break, true}
```

### Notes

```elixir
{:note, "This is a note"}
```

### Boneyard

```elixir
{:boneyard, "commented out fountain content"}
```

### Section

```elixir
{:section, [level: 1, text: "Act One"]}
```

### Synopsis

```elixir
{:synopsis, "Opening movement of the story"}
```

## Inline emphasis

Inline emphasis should not block completion of the structural parser.

Recommended approach:

- complete block-level parsing first
- preserve raw text in action/dialogue/lyrics nodes initially
- add inline emphasis parsing as a second pass or optional mode later

## Parser architecture

Refactor the parser into explicit phases.

### Phase A: normalization

- normalize line endings
- split into lines
- preserve line ordering
- optionally annotate lines with line numbers for diagnostics

### Phase B: title-page extraction

- consume title-page lines at the top of the document
- stop at the first screenplay body content
- support multiline title values if needed

### Phase C: block classification

Classify each line or block as one of:

- scene heading
- transition
- character
- parenthetical
- dialogue line
- lyrics
- centered text
- section
- synopsis
- note
- boneyard start/end
- page break
- action
- blank

### Phase D: block grouping

Group classified lines into higher-level units:

- scene
- action block
- dialogue block
- lyrics block
- boneyard block

### Phase E: AST emission

Transform grouped blocks into the final atom-tagged output tuples.

### Phase F: validation and warnings

Add best-effort diagnostics for malformed constructs.

## Internal parser state

Move from an ad hoc reducer to explicit parser state, for example:

```elixir
%{
  scenes: [],
  current_scene: [],
  pending_dialogue: nil,
  pending_action: [],
  in_boneyard: false,
  errors: [],
  line_number: 0
}
```

This will make it easier to support multiline action, multiline dialogue, lyrics, notes, boneyard, and diagnostics.

## Parsing precedence

Recommended precedence order for classification:

1. boneyard delimiters
2. notes
3. page breaks
4. sections
5. synopses
6. centered text
7. forced scene headings
8. scene headings
9. transitions
10. character cues
11. parentheticals
12. lyrics
13. dialogue continuation
14. action

These precedence rules should be documented in tests as well as code.

## Top-level versus in-scene elements

Recommended policy:

- keep `:section` and `:synopsis` as top-level `script` elements when they function as outline/document structure
- keep flow elements such as notes, boneyard, page breaks, centered text, action, dialogue, and lyrics inside scenes when they occur in screenplay flow
- allow top-level body elements before the first scene heading if the input does not begin with a scene heading

## Error handling strategy

Prefer best-effort parsing with warnings over hard failure.

Possible extended API:

```elixir
Scriptreader.parse_with_warnings(text)
# {:ok, ast, warnings}
```

Warnings may look like:

```elixir
[
  {:warning, [line: 23, type: :orphan_parenthetical, text: "(quietly)"]},
  {:warning, [line: 41, type: :unterminated_boneyard]}
]
```

The existing `parse/1` can remain the simple entry point.

## Testing plan

Expand tests into feature-oriented modules:

- `test/title_page_test.exs`
- `test/scene_heading_test.exs`
- `test/dialogue_test.exs`
- `test/dual_dialogue_test.exs`
- `test/action_test.exs`
- `test/transition_test.exs`
- `test/lyrics_test.exs`
- `test/centered_text_test.exs`
- `test/sections_synopses_test.exs`
- `test/notes_boneyard_test.exs`
- `test/page_break_test.exs`
- `test/error_handling_test.exs`
- `test/integration/full_script_test.exs`

Each group should include:

- happy-path cases
- ambiguous cases
- malformed-input cases where relevant

## Suggested implementation order

1. Stabilize the current behavior with more tests for multiline action, multiline dialogue, title-page variants, scripts with no title page, and scripts with no scene heading.
2. Refactor internals into classification plus stateful reduction.
3. Add structural constructs first: transitions, centered text, page breaks, sections, synopses, notes, and boneyard.
4. Add lyrics.
5. Tighten ambiguity handling for forced headings, character-versus-action, and transition-versus-action cases.
6. Add warnings and malformed-input handling.
7. Add inline emphasis parsing if still required for this PR.

## Definition of done

This PR should be considered complete when:

- all listed Fountain block-level elements are parsed
- the atom-tagged output shape is documented
- tests exist for every supported construct
- warning/error behavior is implemented and tested
- README is updated with representative examples and limitations
