# Code coverage - NI-APT task 1

I've decided to implement my code coverage tool in ruby. I plan to use ruby in next exercises as well, thus I placed some ruby-related files (`Gemfile` and `Gemfile.lock` -- very much analogous to `package.json` and `package-lock.json` for JS/TS) on root level of the whole repo. This is mainly for ease of use (fetching dependencies using `bundle`) in the CI.

## Interfacing with the tool using Makefile

In the code coverage directory, you can use `make` with following options:

  * `run` -- instruments `.c` files in `TARGET_COV` dir (outputs into `./out`). If you want, you can specify both in cli by running `./instrument.rb "path/to/target" "path/to/out/"`.

  * `test` -- runs the tool on all tests in `tests/test_source_files/`. For each tool run, it uses simplecov (more below) to calculate tools own coverage. After whole test suite is finished, final coverage report is stored in newly generated dir `coverage`.
  
  * `benchmark` -- runs benchmark on same files as `test` and calculates average slowdown from all the slowdowns. Files are executed many times (default is 1000 each binary -- 2k runs per test file) to make the results a bit more robust, otherwise I saw swings in slowdown. 
  
  * `build` -- to match course specs. Does nothing 😏

## Methods used & `.c` files parsing 

For the method of doing code coverage, I chose the first one talked about during the course, that being instrumenting `.c` files to count the coverage during execution and using [tree-sitter](https://tree-sitter.github.io/tree-sitter/). There are no official bindings of this tool for ruby, but there exists unofficial ones: 

* [ruby-tree-sitter](https://github.com/Faveod/ruby-tree-sitter) 
* [tree_stand](https://github.com/Shopify/tree_stand) -- high level wrapper for the binding above. I've mainly used this. ([Official documentation](https://shopify.github.io/tree_stand/TreeStand.html)) 

To measure code coverage of my own tool, I've used [SimpleCov](https://github.com/simplecov-ruby/simplecov) tool for ruby.

## Architecture (`src` files)

in `src/` will be (or already are) 3 main parts of the code coverage tool:

1. `FileModel.rb` -- Entry point which *describes* given `.c` file for later ease of use. It runs `tree_stand` on the file to retrieve the AST, then processes it to extract information, such as `line_starts` and `line_count`. It also implements methods for working with the AST. It is passed to the second part as instance, where it holds the information mentioned about specific `.c` file.

2. `Analyzer.rb` -- Takes in instance of `FileModel` and Analyzes the AST with it. It identifies main (if present) and walks all the functions. It specifically searches for lines we will instrument and handles deduping to for example not increment same line twice in case of something like `x++;y++;` + priorities (`:cond_*` before `:pre`). It notes lines and tags how we will instrument them -- `:pre` for simply adding increment right before and `:cond_*` for instrumenting conditionals. It **DOES NOT** write to the file or do any modifications yet, it returns `FilePlan` struct which holds all the important metadata and will be used in the next step to actually apply instrumentation.

3. `Instrumentor.rb` -- Takes in both `FileModel` instance and `FilePlan` of each file it is about to process. It has 2 main phases:
   
   1. **Planning edits** -- `plan_edits(file_models:, file_plans:)` -- for each file, go over lines noted for instrumentation in their respective `FilePlan`s and queue their edits (does not act on them yet). Also queue injection of prologue headers at the start of each file. If file contains `main`, we also inject code to bring coverage reports from all other files and define function to be executed once we exit program (via `atexit`). This function (`__apt_write_lcov`) will write the final `.lcov` file. Lastly, we sort edits so that in the next phase, we modify bottom-up and thus edit offsets dont ivalidate.
   
   2. **Instrumenting** -- `instrument_files` -- In this phase we finally apply edits specified for each file. If the site of edit was of type `:pre` --> edit is of type `:insert`, we simply insert increment *right before* (literally insert at the byte the statement begins). for `:cond_*`-->`:replace`, we replace the condition with comma expresion (`if/while/for (COND)` --> `if/while/for (increment,(COND))`). I think this is fine as we will increase at the moment we reached the line, as was specified in the task (we will increment even if `COND` evaluates to `false`).

Lastly, `instrument.rb` in the root of this task directory is used as the interface we launch to instrument files in a given directory.

## What we instrument

Since ASTs are created by **Tree stand** ~ **Tree sitter**, The main method of finding sites to instrument I used was walking the AST (only inside function bodies) and checking for the following AST node types/tokens (code snippet from `src/Analyzer.rb`):

```ruby
  EXEC_PRE_TYPES  = %w[expression_statement return_statement break_statement continue_statement goto_statement declaration].freeze
  EXEC_HEAD_TYPES = %w[if_statement while_statement for_statement].freeze
```

`EXEC_PRE_TYPES` contains tokens for which we just prepend the increment right before. For `EXEC_HEAD_TYPES`, we transform their condition to comma expresion as mentioned above.

Below is example of a `main` being transformed in single file program:

```c
// other code, this is line 15
int main(int argc, char **argv)
{
    printf("Hello %d", doubler(6)); // line 18
    return 0;                       // line 19
}

```
```c
int main(int argc, char **argv)
{/* __APT_COV__ init */ atexit(__apt_write_lcov);
__apt_register_test1_c_3bcb8323();

    __apt_hits_test1_c_3bcb8323[18]++; /*__APT_COV__*/ printf("Hello %d", doubler(6));
    __apt_hits_test1_c_3bcb8323[19]++; /*__APT_COV__*/ return 0;
}
```
and here example with `cond_*` transform into comma expression:

```c
long factorial(long n)
{
    if (n == 0)
    {
        return 1;
    }
    else
    {
        return n * factorial(n - 1);
    }
}
```
```c
long factorial(long n)
{
    if (__apt_hits_test2_c_17ad8002[5]++, (n == 0))
    {
        __apt_hits_test2_c_17ad8002[7]++; /*__APT_COV__*/ return 1;
    }
    else
    {
        __apt_hits_test2_c_17ad8002[11]++; /*__APT_COV__*/ return n * factorial(n - 1);
    }
}
```

## Mutliple `.c` files

Program should work with multiple `.c` files as long as they are properly structured into separate translation units ~ they have proper `.h` files and we use those for includes.

# Testing

When running `make test`, line coverage calculated by simplecov of my tool is 92.61% (view in browser by opening [`coverage/index.html`](/code-coverage/coverage/index.html)).

From the grader it seems to pass all the tests.

# Benchmark

Slow-down of instrumentation: ~ 1.2x (fluctuates between 1.15-1.25x for me)