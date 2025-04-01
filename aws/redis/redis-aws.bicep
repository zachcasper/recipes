/*
Copyright 2023 The Radius Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

extension aws

@description('Radius-provided object containing information about the resource calling the Recipe')
param context object

@description('Node type for the MemoryDB cluster')
param nodeType string = 'db.t4g.small'

@description('ACL name for the MemoryDB cluster')
param aclName string = 'open-access'

@description('Number of replicas per shard for the MemoryDB cluster')
param numReplicasPerShard int = 0



param memoryDBClusterName string = 'memorydb-cluster-${uniqueString(context.resource.id)}'
resource memoryDBCluster 'AWS.MemoryDB/Cluster@default' = {
  alias: memoryDBClusterName
  properties: {
    ClusterName: memoryDBClusterName
    NodeType: nodeType
    ACLName: aclName
    NumReplicasPerShard: numReplicasPerShard
    Tags: [
      {
        Key: 'radapp.io/environment'
        Value: context.environment.id
      }
      {
        Key: 'radapp.io/application'
        Value: context.application.id
      }
      {
        Key: 'radapp.io/resource'
        Value: context.resource.id
      }
    ]
  }
}

output result object = {
  values: {
    host: memoryDBCluster.properties.ClusterEndpoint.Address
    port: memoryDBCluster.properties.ClusterEndpoint.Port
    tls: true
  }
}
