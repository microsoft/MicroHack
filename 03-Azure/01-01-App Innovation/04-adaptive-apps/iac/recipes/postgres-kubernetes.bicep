@description('Radius-provided recipe context.')
param context object

@description('PostgreSQL database name.')
param database string = 'trading'

@description('PostgreSQL username.')
param user string = 'trade'

@secure()
@description('PostgreSQL password.')
#disable-next-line secure-parameter-default
param password string = '${uniqueString(context.resource.id)}Aa1!'

@description('PostgreSQL container image tag.')
param tag string = '16-alpine'

var memoryBySize = {
  S: '512Mi'
  M: '1Gi'
  L: '2Gi'
}
var sizeKey = context.resource.properties.?size ?? 'S'
var uniqueName = 'postgres-${uniqueString(context.resource.id)}'
var schemaSql = loadTextContent('trading-schema.sql')
var schemaRevision = take(uniqueString(schemaSql), 8)
var port = 5432

extension kubernetes with {
  kubeConfig: ''
  namespace: context.runtime.kubernetes.namespace
} as k8s

resource credentials 'core/Secret@v1' = {
  metadata: {
    name: '${uniqueName}-credentials'
    labels: {
      resource: context.resource.name
      'radapp.io/application': context.application == null ? '' : context.application.name
    }
  }
  stringData: {
    password: password
  }
  type: 'Opaque'
}

resource initSql 'core/ConfigMap@v1' = {
  metadata: {
    name: '${uniqueName}-schema-${schemaRevision}'
    labels: {
      resource: context.resource.name
      'radapp.io/application': context.application == null ? '' : context.application.name
    }
  }
  data: {
    'init.sql': schemaSql
  }
}

resource postgresql 'apps/Deployment@v1' = {
  metadata: {
    name: uniqueName
    labels: {
      app: 'postgresql'
      resource: context.resource.name
      'radapp.io/application': context.application == null ? '' : context.application.name
    }
  }
  spec: {
    replicas: 1
    selector: {
      matchLabels: {
        app: 'postgresql'
        resource: context.resource.name
      }
    }
    template: {
      metadata: {
        labels: {
          app: 'postgresql'
          resource: context.resource.name
          'radapp.io/application': context.application == null ? '' : context.application.name
        }
      }
      spec: {
        containers: [
          {
            name: 'postgres'
            image: 'postgres:${tag}'
            ports: [
              {
                containerPort: port
                name: 'postgres'
              }
            ]
            env: [
              {
                name: 'POSTGRES_USER'
                value: user
              }
              {
                name: 'POSTGRES_PASSWORD'
                valueFrom: {
                  secretKeyRef: {
                    name: credentials.metadata.name
                    key: 'password'
                  }
                }
              }
              {
                name: 'POSTGRES_DB'
                value: database
              }
            ]
            readinessProbe: {
              exec: {
                command: [
                  'pg_isready'
                  '-U'
                  user
                  '-d'
                  database
                ]
              }
              initialDelaySeconds: 5
              periodSeconds: 5
              failureThreshold: 12
            }
            resources: {
              requests: {
                memory: memoryBySize[sizeKey]
              }
            }
            volumeMounts: [
              {
                name: 'init-sql'
                mountPath: '/docker-entrypoint-initdb.d'
                readOnly: true
              }
            ]
          }
        ]
        volumes: [
          {
            name: 'init-sql'
            configMap: {
              name: initSql.metadata.name
            }
          }
        ]
      }
    }
  }
}

resource service 'core/Service@v1' = {
  metadata: {
    name: uniqueName
    labels: {
      resource: context.resource.name
    }
  }
  spec: {
    type: 'ClusterIP'
    selector: {
      app: 'postgresql'
      resource: context.resource.name
    }
    ports: [
      {
        name: 'postgres'
        port: port
        targetPort: 'postgres'
      }
    ]
  }
}

resource schemaInitializer 'batch/Job@v1' = {
  metadata: {
    name: '${uniqueName}-schema-${schemaRevision}'
    labels: {
      app: 'postgres-schema-initializer'
      resource: context.resource.name
      'radapp.io/application': context.application == null ? '' : context.application.name
    }
  }
  spec: {
    backoffLimit: 6
    activeDeadlineSeconds: 900
    template: {
      metadata: {
        labels: {
          app: 'postgres-schema-initializer'
          resource: context.resource.name
        }
      }
      spec: {
        restartPolicy: 'Never'
        containers: [
          {
            name: 'schema-initializer'
            image: 'postgres:${tag}'
            command: [
              'sh'
              '-ceu'
              '''
for attempt in $(seq 1 60); do
  if psql --set=ON_ERROR_STOP=1 --file=/schema/init.sql; then
    exit 0
  fi
  echo "PostgreSQL is not ready for schema initialization (attempt ${attempt}/60)." >&2
  sleep 5
done
exit 1
'''
            ]
            env: [
              {
                name: 'PGHOST'
                value: service.metadata.name
              }
              {
                name: 'PGPORT'
                value: string(port)
              }
              {
                name: 'PGDATABASE'
                value: database
              }
              {
                name: 'PGUSER'
                value: user
              }
              {
                name: 'PGPASSWORD'
                valueFrom: {
                  secretKeyRef: {
                    name: credentials.metadata.name
                    key: 'password'
                  }
                }
              }
            ]
            volumeMounts: [
              {
                name: 'schema'
                mountPath: '/schema'
                readOnly: true
              }
            ]
          }
        ]
        volumes: [
          {
            name: 'schema'
            configMap: {
              name: initSql.metadata.name
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    postgresql
  ]
}

output result object = {
  resources: [
    '/planes/kubernetes/local/namespaces/${context.runtime.kubernetes.namespace}/providers/core/Secret/${credentials.metadata.name}'
    '/planes/kubernetes/local/namespaces/${context.runtime.kubernetes.namespace}/providers/core/ConfigMap/${initSql.metadata.name}'
    '/planes/kubernetes/local/namespaces/${context.runtime.kubernetes.namespace}/providers/apps/Deployment/${postgresql.metadata.name}'
    '/planes/kubernetes/local/namespaces/${context.runtime.kubernetes.namespace}/providers/core/Service/${service.metadata.name}'
    '/planes/kubernetes/local/namespaces/${context.runtime.kubernetes.namespace}/providers/batch/Job/${schemaInitializer.metadata.name}'
  ]
  values: {
    host: '${service.metadata.name}.${context.runtime.kubernetes.namespace}.svc.cluster.local'
    port: port
    database: database
    username: user
  }
  secrets: {
    #disable-next-line outputs-should-not-contain-secrets
    password: password
  }
}
