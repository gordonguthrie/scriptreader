defmodule ScriptreaderTest do
  use ExUnit.Case

  test "parses title page, scene, and dialogue structure" do
    script = """
    Title: Example Script
    Author: Jane Doe

    INT. HOUSE - DAY

    A room with a table.

    ALICE
    (quietly)
    We should go.
    """

    parsed = Scriptreader.parse(script)

    assert parsed[:title] == [title: "Example Script", author: "Jane Doe"]

    assert [{:scene, scene}] = parsed[:script]
    assert {:heading, "INT. HOUSE - DAY"} in scene
    assert {:action, "A room with a table."} in scene

    assert {:dialogue, dialogue} = Enum.find(scene, fn {tag, _value} -> tag == :dialogue end)

    assert dialogue[:character] == "ALICE"
    assert dialogue[:parenthesis] == ["(quietly)"]
    assert dialogue[:dialog] == "We should go."
    assert dialogue[:simultaneous] == false
  end

  test "parses multiple scenes and simultaneous dialogue marker" do
    script = """
    INT. ROOM - DAY

    ALICE^
    (whispering)
    We're late.

    EXT. STREET - NIGHT

    BOB
    Run!
    """

    parsed = Scriptreader.parse(script)

    assert length(parsed[:script]) == 2
    assert {:scene, first_scene} = Enum.at(parsed[:script], 0)
    assert {:scene, second_scene} = Enum.at(parsed[:script], 1)

    assert {:dialogue, first_dialogue} =
             Enum.find(first_scene, fn {tag, _value} -> tag == :dialogue end)

    assert first_dialogue[:character] == "ALICE"
    assert first_dialogue[:simultaneous] == true
    assert first_dialogue[:parenthesis] == ["(whispering)"]
    assert first_dialogue[:dialog] == "We're late."

    assert {:dialogue, second_dialogue} =
             Enum.find(second_scene, fn {tag, _value} -> tag == :dialogue end)

    assert second_dialogue[:character] == "BOB"
    assert second_dialogue[:simultaneous] == false
    assert second_dialogue[:dialog] == "Run!"
  end
end
