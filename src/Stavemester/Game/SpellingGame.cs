namespace Stavemester.Game;

/// <param name="ShowFirstLetter">Whether the word starts with its first letter already filled in.</param>
public sealed record GameLevel(int Number, string Name, string Description, bool ShowFirstLetter);

/// <summary>One entry in ordbog.json.</summary>
/// <param name="Image">An emoji, or a file name in wwwroot/images (e.g. "hest.jpg").</param>
/// <param name="Sound">Optional file name in wwwroot/sounds (e.g. "hest.mp3"), played when the word is shown.</param>
public sealed record WordEntry(string Word, string Image, string? Sound = null)
{
    private static readonly string[] ImageExtensions = [".jpg", ".jpeg", ".png", ".webp", ".gif", ".svg"];

    public bool IsImageFile => ImageExtensions.Any(ext => Image.EndsWith(ext, StringComparison.OrdinalIgnoreCase));

    public string ImageUrl => $"images/{Image}";

    public string? SoundUrl => string.IsNullOrWhiteSpace(Sound) ? null : $"sounds/{Sound}";

    /// <summary>The word as the capital letters the child has to type.</summary>
    public string Letters => Word.Trim().ToUpperInvariant();
}

public sealed class SpellingGame
{
    public static readonly IReadOnlyList<GameLevel> Levels =
    [
        new(1, "Niveau 1", "Med første bogstav", true),
        new(2, "Niveau 2", "Uden hjælp", false),
    ];

    /// <summary>The Danish alphabet, in the order the keyboard shows it.</summary>
    public const string Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZÆØÅ";

    private readonly Random _random = new();
    private readonly Queue<WordEntry> _deck = new();
    private IReadOnlyList<WordEntry> _words = [];

    public GameLevel Level { get; private set; } = Levels[0];

    public WordEntry? Current { get; private set; }

    /// <summary>How many letters of the current word are filled in.</summary>
    public int Filled { get; private set; }

    /// <summary>The position of the letter the ? button revealed, if any.</summary>
    public int? HintAt { get; private set; }

    public bool HasWords => _words.Count > 0;

    public bool IsSolved => Current is not null && Filled == Current.Letters.Length;

    public char? NextLetter => Current is null || IsSolved ? null : Current.Letters[Filled];

    public void SetWords(IEnumerable<WordEntry> words)
    {
        // Only words made of keyboard letters can be spelled.
        _words = words.Where(w => w.Letters.Length > 0 && w.Letters.All(Alphabet.Contains)).ToList();
        _deck.Clear();
    }

    public void SetLevel(GameLevel level) => Level = level;

    /// <summary>Moves to the next word. Every word comes once before any repeats, in random order.</summary>
    public void NewRound()
    {
        if (_words.Count == 0) return;

        if (_deck.Count == 0)
        {
            var shuffled = _words.ToArray();
            _random.Shuffle(shuffled);
            // Don't start the new pass with the word we just had.
            if (shuffled.Length > 1 && shuffled[0] == Current)
                (shuffled[0], shuffled[^1]) = (shuffled[^1], shuffled[0]);
            foreach (var word in shuffled) _deck.Enqueue(word);
        }

        Current = _deck.Dequeue();
        Filled = Level.ShowFirstLetter ? 1 : 0;
        HintAt = null;
    }

    /// <summary>Restarts the current word, e.g. after switching level.</summary>
    public void RestartWord()
    {
        Filled = Level.ShowFirstLetter ? 1 : 0;
        HintAt = null;
    }

    /// <summary>Fills in the next box if the letter is right.</summary>
    public bool TryLetter(char letter)
    {
        if (NextLetter != letter) return false;
        Filled++;
        HintAt = null;
        return true;
    }

    /// <summary>Shows the next letter in its box, which the child then finds on the keyboard.</summary>
    public void Hint()
    {
        if (!IsSolved) HintAt = Filled;
    }
}
