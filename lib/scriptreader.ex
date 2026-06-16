defmodule Scriptreader do
  @moduledoc """
  Parser for Fountain screenplay markup.
  """

  @title_keys %{
    "title" => :title,
    "credit" => :credit,
    "author" => :author,
    "authors" => :author,
    "source" => :source,
    "notes" => :notes,
    "draft date" => :draft_date,
    "draft_date" => :draft_date,
    "date" => :date,
    "contact" => :contact,
    "copyright" => :copyright
  }

  @doc """
  Parse Fountain text into atom-tagged tuples with minimal nesting.
  """
  @spec parse(String.t()) :: keyword()
  def parse(text) when is_binary(text) do
    lines =
      text
      |> String.replace("\r\n", "\n")
      |> String.replace("\r", "\n")
      |> String.split("\n", trim: false)

    {title_lines, body_lines} = split_title_and_body(lines)

    [
      title: parse_title(title_lines),
      script: parse_script(body_lines)
    ]
  end

  defp split_title_and_body(lines) do
    {title_lines, rest} =
      Enum.split_while(lines, fn line ->
        trimmed = String.trim(line)
        trimmed != "" and String.contains?(trimmed, ":")
      end)

    has_title? = title_lines != [] and Enum.any?(title_lines, &String.contains?(&1, ":"))

    if has_title? do
      {title_lines, Enum.drop_while(rest, &(String.trim(&1) == ""))}
    else
      {[], lines}
    end
  end

  defp parse_title(lines) do
    Enum.map(lines, fn line ->
      [key, value] = String.split(line, ":", parts: 2)
      key = key |> String.trim() |> String.downcase()
      value = String.trim(value)

      case Map.get(@title_keys, key) do
        nil -> {:meta, {String.trim(key), value}}
        atom_key -> {atom_key, value}
      end
    end)
  end

  defp parse_script(lines) do
    {scenes, current_scene, pending_dialogue} =
      Enum.reduce(lines, {[], [], nil}, fn line, {scenes, current_scene, pending_dialogue} ->
        trimmed = String.trim(line)

        cond do
          trimmed == "" ->
            next_scene =
              case pending_dialogue do
                nil -> current_scene
                dialogue -> current_scene ++ [dialogue]
              end

            {scenes, next_scene, nil}

          scene_heading?(trimmed) ->
            scenes =
              if current_scene == [] do
                scenes
              else
                scenes ++ [{:scene, current_scene}]
              end

            {scenes, [{:heading, normalize_heading(trimmed)}], nil}

          character_line?(trimmed) ->
            {name, simultaneous} = parse_character(trimmed)

            dialogue =
              {:dialogue,
               [character: name, parenthesis: [], dialog: "", simultaneous: simultaneous]}

            next_scene =
              case pending_dialogue do
                nil -> current_scene
                previous -> current_scene ++ [previous]
              end

            {scenes, next_scene, dialogue}

          parenthetical?(trimmed) and pending_dialogue != nil ->
            {:dialogue, dialogue} = pending_dialogue
            parents = Keyword.get(dialogue, :parenthesis, [])
            updated = {:dialogue, Keyword.put(dialogue, :parenthesis, parents ++ [trimmed])}
            {scenes, current_scene, updated}

          pending_dialogue != nil ->
            {:dialogue, dialogue} = pending_dialogue
            dialog_text = Keyword.get(dialogue, :dialog)
            updated_text = if dialog_text == "", do: trimmed, else: dialog_text <> "\n" <> trimmed
            {scenes, current_scene, {:dialogue, Keyword.put(dialogue, :dialog, updated_text)}}

          true ->
            {scenes, current_scene ++ [{:action, trimmed}], nil}
        end
      end)

    final_scene =
      case pending_dialogue do
        nil -> current_scene
        dialogue -> current_scene ++ [dialogue]
      end

    scenes =
      if final_scene == [] do
        scenes
      else
        scenes ++ [{:scene, final_scene}]
      end

    scenes
  end

  defp scene_heading?(line) do
    String.starts_with?(line, ".") or
      String.match?(line, ~r/^(INT\.|EXT\.|EST\.|INT\/EXT\.|I\/E\.)/)
  end

  defp normalize_heading("." <> rest), do: String.trim(rest)
  defp normalize_heading(line), do: line

  defp character_line?(line) do
    line == String.upcase(line) and
      not String.contains?(line, ":") and
      not scene_heading?(line)
  end

  defp parse_character(line) do
    if String.ends_with?(line, "^") do
      {line |> String.trim_trailing("^") |> String.trim(), true}
    else
      {line, false}
    end
  end

  defp parenthetical?(line) do
    String.starts_with?(line, "(") and String.ends_with?(line, ")")
  end
end
