# Dalek Attack Character Builder – Research Handover Pack

This pack records the research completed to date for a proposed **Dalek Attack playable-character builder**.

It is deliberately separate from the existing character extraction/editor work. The intended development path is:

`Character Builder -> assembled 45-frame indexed sprite sheet -> existing Dalek character tool/import/export pipeline`

The builder is **not yet an application feature**. Research has focused on:

- the meaning and relationships of all 45 original character frames;
- exact left/right mirroring;
- reusable sprite-component boundaries;
- pose families and layering;
- coats, scarves, hands, equipment and other overlays;
- exact frame-0 reconstruction from isolated components;
- the minimum further analysis required before implementation.

## Suggested repository placement

The Markdown files are numbered to follow the existing `docs/01`–`docs/10` research set without replacing it:

- `docs/11-character-builder-research.md`
- `docs/12-character-builder-component-and-layer-model.md`
- `docs/13-character-builder-analysis-method.md`
- `docs/14-character-builder-implementation-plan.md`
- `docs/15-character-builder-handover.md`

Reference material may be placed under a working/research directory, for example:

- `work/character_builder_research/char1-parts.iff`
- `work/character_builder_research/char2-parts.iff`
- `work/character_builder_research/char1-parts-preview.png`
- `work/character_builder_research/char2-parts-preview.png`
- `work/character_builder_research/char2_frame0_reconstruction_proof.png`
- `work/character_builder_research/char2_stage3_component_spec.json`

**Naming warning:** the user-supplied file `char1-parts.iff` actually contains **CHAR2 frame 0** component material. Preserve the original filename if desired, but document this fact to avoid later confusion.

## Recommended reading order

1. `11-character-builder-research.md`
2. `12-character-builder-component-and-layer-model.md`
3. `13-character-builder-analysis-method.md`
4. `14-character-builder-implementation-plan.md`
5. `15-character-builder-handover.md`

The final document is designed to be pasted or handed directly to a new ChatGPT/Codex thread.
