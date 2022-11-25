# Prepare composer

This action copies dependencies already present in a previously installed composer directory, so that the composer doesn't redownload what is not supposed to redownload, or removes what it's not supposed to remove.

Needs to run before composer install is run.

## Getting Started

The following example will copy dependencies from `previous` to `source`

```yml
- name: Prepare Composer
  uses: saucal/action-prepare-composer@v1
  with:
    path: "source"
    from: "previous"
```

## Full options

```yml
- uses: saucal/action-prepare-composer@v1
  with:
    # Path with previously installed dependencies
    from: ""

    # Path that you're installing dependencies to
    path: ""
```
