
class Queries

  @insertCharacter: (name, species, pet, crush) ->
    return insertCharacterQuery =
      text: """
        INSERT INTO Characters (name, species, pet, crush)
        VALUES ($1, $2, $3, $4);
        """
      values: [name, species, pet, crush]

  @selectCharacter: (name) ->
    return selectCharacterQuery =
      text: """
        SELECT name, species, pet, crush
        FROM Characters
        WHERE name = $1;
        """
      values: [name]

module.exports = Queries
