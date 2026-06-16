# scriptreader

A small Elixir library for parsing Fountain screenplay markup into atom-tagged tuples.

## Usage

```elixir
Scriptreader.parse(script_text)
#=> [
#=>   title: [title: "Example", author: "A. Writer"],
#=>   script: [
#=>     {:scene, [{:heading, "INT. ROOM - DAY"}, {:action, "Some action..."}]}
#=>   ]
#=> ]
```
