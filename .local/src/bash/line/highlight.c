#include "line.h"

#include <limits.h>
#include <sys/stat.h>
#include <unistd.h>

enum style {
  STYLE_PLAIN,
  STYLE_COMMAND,
  STYLE_PRECOMMAND,
  STYLE_RESERVED,
  STYLE_UNKNOWN,
  STYLE_AUTODIRECTORY,
  STYLE_PATH,
  STYLE_QUOTED,
  STYLE_REDIRECTION,
  STYLE_COMMENT,
  STYLE_COUNT
};

static const char *const sgr[STYLE_COUNT] = {
    [STYLE_PLAIN] = "",
    [STYLE_COMMAND] = "32",
    [STYLE_PRECOMMAND] = "32;4",
    [STYLE_RESERVED] = "33",
    [STYLE_UNKNOWN] = "1;31",
    [STYLE_AUTODIRECTORY] = "32;4",
    [STYLE_PATH] = "4",
    [STYLE_QUOTED] = "33",
    [STYLE_REDIRECTION] = "33",
    [STYLE_COMMENT] = "1;30"};

enum expect { COMMAND_WORD, ARGUMENT, PRECOMMAND_OPTION, OPTION_ARGUMENT };

struct precommand {
  const char *name, *options_with_argument;
};

/* INFO: fc 25sep26 zsh-syntax-highlighting's precommand_options, the ones that exist on Linux */
static const struct precommand precommands[] = {
    {"builtin", ""},   {"command", ""},     {"exec", "a"},    {"doas", "aCu"},
    {"nice", "n"},     {"pkexec", ""},      {"sudo", "Cgprtu"}, {"run0", "ugD"},
    {"stdbuf", "ioe"}, {"eatmydata", ""},   {"nohup", ""},    {"setsid", ""},
    {"env", "u"},      {"ionice", "cnt"},   {"strace", "IbeaosXPpEuOS"},
    {"chronic", ""},   {"ifne", ""},        {NULL, NULL}};

static const char *const reserved_before_command[] = {
    "if", "then", "else", "elif", "do", "while", "until", "!", "time", "{", "coproc", NULL};

struct scan {
  const char *line;
  int end;
  char *styles;
  enum expect expect;
  const char *options_with_argument;
};

static void mark(struct scan *s, int from, int to, enum style style)
{
  memset(s->styles + from, style, to - from);
}

static int clamp(struct scan *s, int i)
{
  return i < s->end ? i : s->end;
}

static int after_single_quote(struct scan *s, int i)
{
  while (i < s->end && s->line[i] != '\'')
    i++;
  return clamp(s, i + 1);
}

static int after_escaped_quote(struct scan *s, int i, char quote)
{
  while (i < s->end && s->line[i] != quote)
    i += s->line[i] == '\\' ? 2 : 1;
  return clamp(s, i + 1);
}

static int after_parentheses(struct scan *s, int i)
{
  int depth = 0;

  while (i < s->end) {
    char c = s->line[i];
    if (c == '\\')
      i += 2;
    else if (c == '\'')
      i = after_single_quote(s, i + 1);
    else if (c == '"')
      i = after_escaped_quote(s, i + 1, '"');
    else {
      if (c == '(')
        depth++;
      else if (c == ')' && --depth == 0)
        return i + 1;
      i++;
    }
  }
  return s->end;
}

/* 0 when i is not at a quote, else the index after the quoted text. */
static int after_quote_at(struct scan *s, int i)
{
  const char *l = s->line;

  if (l[i] == '\'')
    return after_single_quote(s, i + 1);
  if (l[i] == '"')
    return after_escaped_quote(s, i + 1, '"');
  if (l[i] == '$' && i + 1 < s->end && l[i + 1] == '\'')
    return after_escaped_quote(s, i + 2, '\'');
  return 0;
}

static int is_metacharacter(char c)
{
  return c == ' ' || (c && strchr("|&;()<>", c));
}

static int word_end(struct scan *s, int i)
{
  const char *l = s->line;

  while (i < s->end && !is_metacharacter(l[i])) {
    int quoted = after_quote_at(s, i);
    if (quoted)
      i = quoted;
    else if (l[i] == '\\')
      i = clamp(s, i + 2);
    else if (l[i] == '`')
      i = after_escaped_quote(s, i + 1, '`');
    else if (l[i] == '$' && i + 1 < s->end && l[i + 1] == '(')
      i = after_parentheses(s, i + 1);
    else
      i++;
  }
  return i;
}

static int redirection_end(struct scan *s, int i)
{
  const char *l = s->line;
  int j = i;

  while (j < s->end && l[j] >= '0' && l[j] <= '9')
    j++;
  if (j < s->end && l[j] == '&' && j + 1 < s->end && l[j + 1] == '>')
    j++;
  if (j >= s->end || (l[j] != '<' && l[j] != '>'))
    return i;
  while (j < s->end && strchr("<>&|", l[j]) && l[j])
    j++;
  if (j < s->end && l[j] == '-')
    j++;
  return j;
}

static int separator_end(struct scan *s, int i)
{
  const char *l = s->line;
  char c = l[i], next = i + 1 < s->end ? l[i + 1] : '\0';

  if (c == '(' || c == ')')
    return i + 1;
  if (next == c || (c == '|' && next == '&') || (c == ';' && next == '&'))
    return i + 2;
  return i + 1;
}

/* -1 when the word has an expansion, so only running it can tell what it names. */
static int unquote(const char *word, int length, char *out, int size, int *quoted)
{
  int i = 0, n = 0;
  char quote = 0;

  *quoted = 0;
  while (i < length) {
    char c = word[i++];
    if (quote == '\'' && c == '\'')
      quote = 0;
    else if (quote == '\'')
      out[n++] = c;
    else if (c == '\\' && i < length)
      out[n++] = word[i++], *quoted = 1;
    else if (c == '$' || c == '`' || (!quote && (c == '*' || c == '?')))
      return -1;
    else if (c == '"')
      quote = quote ? 0 : '"', *quoted = 1;
    else if (c == '\'' && !quote)
      quote = '\'', *quoted = 1;
    else
      out[n++] = c;
    if (n >= size)
      return -1;
  }
  out[n] = '\0';
  return 0;
}

static int is_name_character(char c, int first)
{
  return c == '_' || ((c | 32) >= 'a' && (c | 32) <= 'z') || (!first && c >= '0' && c <= '9');
}

static int is_assignment(const char *word, int length)
{
  int i = 0;

  if (length == 0 || !is_name_character(word[0], 1))
    return 0;
  while (i < length && is_name_character(word[i], 0))
    i++;
  if (i < length && word[i] == '[') {
    while (i < length && word[i] != ']')
      i++;
    i++;
  }
  if (i < length && word[i] == '+')
    i++;
  return i < length && word[i] == '=';
}

static int shell_can_run(char *name)
{
  return find_reserved_word(name) >= 0 || find_alias(name) || find_function(name) ||
         find_shell_builtin(name);
}

static int on_path(const char *name)
{
  char *path = find_user_command(name);

  free(path);
  return path != NULL;
}

/* bash tries a name on PATH before autocd takes it as a directory. */
static enum style command_style(char *name)
{
  char *expanded = name[0] == '~' ? bash_tilde_expand(name, 0) : NULL;
  const char *path = expanded ? expanded : name;
  struct stat st;
  int found = stat(path, &st) == 0;
  enum style style;

  if (strchr(path, '/'))
    style = found && S_ISDIR(st.st_mode) ? (autocd ? STYLE_AUTODIRECTORY : STYLE_UNKNOWN)
            : found && S_ISREG(st.st_mode) && access(path, X_OK) == 0 ? STYLE_COMMAND
                                                                        : STYLE_UNKNOWN;
  else if (shell_can_run(name) || on_path(name))
    style = STYLE_COMMAND;
  else
    style = autocd && found && S_ISDIR(st.st_mode) ? STYLE_AUTODIRECTORY : STYLE_UNKNOWN;
  free(expanded);
  return style;
}

static const struct precommand *precommand_named(const char *name)
{
  const struct precommand *p;

  for (p = precommands; p->name; p++)
    if (strcmp(p->name, name) == 0)
      return p;
  return NULL;
}

static int reserved_word_takes_command(const char *word)
{
  const char *const *w;

  for (w = reserved_before_command; *w; w++)
    if (strcmp(*w, word) == 0)
      return 1;
  return 0;
}

static int option_wants_argument(const char *word, int length, const char *options)
{
  int i;

  if (length > 1 && word[1] == '-')
    return 0;
  for (i = 1; i < length; i++)
    if (strchr(options, word[i]))
      return i == length - 1;
  return 0;
}

static void paint_quotes(struct scan *s, int from, int to)
{
  int i = from;

  while (i < to) {
    int quoted = after_quote_at(s, i);
    if (quoted) {
      mark(s, i, quoted, STYLE_QUOTED);
      i = quoted;
    } else
      i += s->line[i] == '\\' ? 2 : 1;
  }
}

static void paint_argument(struct scan *s, int from, int to)
{
  char word[PATH_MAX], *expanded;
  struct stat st;
  int quoted;

  paint_quotes(s, from, to);
  if (s->line[from] == '-' || unquote(s->line + from, to - from, word, sizeof word, &quoted) < 0 ||
      quoted || !*word)
    return;
  expanded = word[0] == '~' ? bash_tilde_expand(word, 0) : NULL;
  if (stat(expanded ? expanded : word, &st) == 0)
    mark(s, from, to, STYLE_PATH);
  free(expanded);
}

static enum expect paint_command(struct scan *s, int from, int to)
{
  char word[PATH_MAX];
  const struct precommand *precommand;
  int quoted;

  if (is_assignment(s->line + from, to - from)) {
    paint_quotes(s, from, to);
    return COMMAND_WORD;
  }
  if (unquote(s->line + from, to - from, word, sizeof word, &quoted) < 0 || !*word)
    return ARGUMENT;
  if (!quoted && find_reserved_word(word) >= 0) {
    mark(s, from, to, STYLE_RESERVED);
    return reserved_word_takes_command(word) ? COMMAND_WORD : ARGUMENT;
  }
  precommand = precommand_named(word);
  if (precommand && command_style(word) == STYLE_COMMAND) {
    mark(s, from, to, STYLE_PRECOMMAND);
    s->options_with_argument = precommand->options_with_argument;
    return PRECOMMAND_OPTION;
  }
  mark(s, from, to, command_style(word));
  return ARGUMENT;
}

static enum expect paint_word(struct scan *s, int from, int to)
{
  const char *word = s->line + from;
  int length = to - from;

  switch (s->expect) {
  case PRECOMMAND_OPTION:
    if (length == 2 && word[0] == '-' && word[1] == '-')
      return COMMAND_WORD;
    if (length > 1 && word[0] == '-')
      return option_wants_argument(word, length, s->options_with_argument) ? OPTION_ARGUMENT
                                                                            : PRECOMMAND_OPTION;
    return paint_command(s, from, to);
  case OPTION_ARGUMENT:
    paint_argument(s, from, to);
    return PRECOMMAND_OPTION;
  case COMMAND_WORD:
    return paint_command(s, from, to);
  default:
    paint_argument(s, from, to);
    return ARGUMENT;
  }
}

static void scan_line(struct scan *s)
{
  const char *l = s->line;
  int i = 0, redirected = 0;

  while (i < s->end) {
    int from = i, to;
    char c = l[i];

    if (c == ' ') {
      i++;
    } else if (c == '#' && interactive_comments) {
      mark(s, i, s->end, STYLE_COMMENT);
      return;
    } else if ((c == '<' || c == '>') && i + 1 < s->end && l[i + 1] == '(') {
      i = after_parentheses(s, i + 1);
    } else if ((to = redirection_end(s, i)) > i) {
      mark(s, from, to, STYLE_REDIRECTION);
      redirected = 1;
      i = to;
    } else if (strchr("|&;()", c)) {
      i = separator_end(s, i);
      s->expect = COMMAND_WORD;
      redirected = 0;
    } else {
      i = word_end(s, i);
      if (redirected)
        paint_argument(s, from, i);
      else
        s->expect = paint_word(s, from, i);
      redirected = 0;
    }
  }
}

static void write_styled(struct scan *s)
{
  int i = 0;

  fprintf(rl_outstream, SAVE_CURSOR);
  screen_move_to(0);
  while (i < s->end) {
    int j = i;
    while (j < s->end && s->styles[j] == s->styles[i])
      j++;
    fprintf(rl_outstream, "\033[0;%sm%.*s", sgr[(int)s->styles[i]], j - i, s->line + i);
    i = j;
  }
  fprintf(rl_outstream, RESET RESTORE_CURSOR);
}

/* Rewrites the whole line, so a word that lost its style does not keep the old one. */
void paint_highlights(void)
{
  struct scan s = {rl_line_buffer, rl_end, calloc(rl_end, 1), COMMAND_WORD, ""};

  if (!s.styles)
    return;
  scan_line(&s);
  write_styled(&s);
  free(s.styles);
}
