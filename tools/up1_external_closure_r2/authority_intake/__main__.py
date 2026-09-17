try:
    from .cli import main
except ImportError:  # permit direct invocation from the authority_intake folder
    from cli import main

raise SystemExit(main())
