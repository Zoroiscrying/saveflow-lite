# Changelog

## 0.1.0

Initial public repository version.

Included in this release:
- `SaveFlowNodeSource` for node-owned object state
- `SaveFlowDataSource` for custom system/model state
- `SaveFlowScope` for domain grouping and restore order
- `SaveFlowEntityCollectionSource` for runtime entity sets
- `SaveFlowPrefabEntityFactory` as the default runtime prefab path
- `SaveFlowEntityFactory` for advanced runtime spawn and lookup logic
- custom inspector previews for core SaveFlow nodes
- demo scenes:
  - plugin sandbox
  - recommended template
  - Zelda-like sample
- runtime test coverage for node, scope, data, and entity workflows

Known current boundaries:
- no first-class reference resolution system yet
- no formal migration pipeline beyond current version fields and contracts
- advanced runtime pooling still requires a custom `SaveFlowEntityFactory`
