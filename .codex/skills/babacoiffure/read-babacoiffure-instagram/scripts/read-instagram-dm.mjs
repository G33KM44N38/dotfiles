#!/usr/bin/env node

import { existsSync, readFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { spawnSync } from 'node:child_process'

const CANONICAL_ENV_FILES = [
    '/Users/boss/coding/work/babacoiffure_monorepo.git/branches/release-/.env',
    '/Users/boss/coding/work/babacoiffure_monorepo.git/branches/main-/.env',
]

const usage = `Usage:
  read-instagram-dm.mjs account [--doppler-project NAME --doppler-config NAME] [--env PATH]
  read-instagram-dm.mjs conversations [--search TEXT] [--limit 1-100] [--pages 1-20] [--doppler-project NAME --doppler-config NAME] [--env PATH]
  read-instagram-dm.mjs messages (--username HANDLE | --conversation-id ID) [--limit 1-100] [--include-text] [--doppler-project NAME --doppler-config NAME] [--env PATH]`

const parseArgs = values => {
    const options = { command: values[0] }

    for (let index = 1; index < values.length; index += 1) {
        const argument = values[index]

        if (argument === '--include-text') {
            options.includeText = true
            continue
        }

        if (!argument.startsWith('--')) {
            throw new Error(`Unexpected argument: ${argument}`)
        }

        const key = argument.slice(2).replace(/-([a-z])/g, (_, letter) =>
            letter.toUpperCase()
        )
        const value = values[index + 1]

        if (!value || value.startsWith('--')) {
            throw new Error(`Missing value for ${argument}`)
        }

        options[key] = value
        index += 1
    }

    return options
}

const parseDotenv = contents => {
    const values = {}

    for (const rawLine of contents.split(/\r?\n/u)) {
        const line = rawLine.trim()
        if (!line || line.startsWith('#')) continue

        const normalized = line.startsWith('export ') ? line.slice(7) : line
        const separator = normalized.indexOf('=')
        if (separator < 1) continue

        const key = normalized.slice(0, separator).trim()
        if (!/^[A-Z_][A-Z0-9_]*$/u.test(key)) continue

        let value = normalized.slice(separator + 1).trim()
        const quote = value[0]

        if ((quote === '"' || quote === "'") && value.endsWith(quote)) {
            value = value.slice(1, -1)
            if (quote === '"') {
                value = value
                    .replace(/\\n/gu, '\n')
                    .replace(/\\r/gu, '\r')
                    .replace(/\\t/gu, '\t')
                    .replace(/\\"/gu, '"')
                    .replace(/\\\\/gu, '\\')
            }
        } else {
            value = value.replace(/\s+#.*$/u, '').trim()
        }

        values[key] = value
    }

    return values
}

const hasInstagramToken = path => {
    if (!existsSync(path)) return false
    const values = parseDotenv(readFileSync(path, 'utf8'))
    return Boolean(values.INSTAGRAM_DM_ACCESS_TOKEN)
}

const findParentEnv = startDirectory => {
    let directory = resolve(startDirectory)

    while (true) {
        const candidate = join(directory, '.env')
        if (hasInstagramToken(candidate)) return candidate

        const parent = dirname(directory)
        if (parent === directory) return undefined
        directory = parent
    }
}

const runDoppler = arguments_ => {
    const result = spawnSync('doppler', arguments_, {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'pipe'],
    })
    return result.status === 0 ? result.stdout.trim() : undefined
}

const runDopplerJson = arguments_ => {
    const output = runDoppler(arguments_)
    if (!output) return undefined
    try {
        return JSON.parse(output)
    } catch {
        return undefined
    }
}

const readDopplerScope = (project, config) => {
    const token = runDoppler([
        'secrets', 'get', 'INSTAGRAM_DM_ACCESS_TOKEN', '--plain',
        '--project', project, '--config', config,
    ])
    if (!token) return undefined

    const values = { INSTAGRAM_DM_ACCESS_TOKEN: token }
    for (const key of [
        'INSTAGRAM_GRAPH_API_BASE_URL',
        'INSTAGRAM_GRAPH_API_VERSION',
        'INSTAGRAM_BUSINESS_ACCOUNT_ID',
        'INSTAGRAM_DM_SYNC_ENABLED',
    ]) {
        const value = runDoppler([
            'secrets', 'get', key, '--plain',
            '--project', project, '--config', config,
        ])
        if (value) values[key] = value
    }
    return { values, source: `doppler:${project}/${config}` }
}

const findDopplerEnvironment = options => {
    const explicitProject = options.dopplerProject || process.env.BABACOIFFURE_DOPPLER_PROJECT
    const explicitConfig = options.dopplerConfig || process.env.BABACOIFFURE_DOPPLER_CONFIG
    const currentProject = runDoppler(['configure', 'get', 'project', '--plain'])
    const currentConfig = runDoppler(['configure', 'get', 'config', '--plain'])
    const scopes = []

    if (explicitProject && explicitConfig) scopes.push([explicitProject, explicitConfig])
    if (currentProject && currentConfig) scopes.push([currentProject, currentConfig])

    if (scopes.length === 0) {
        const projects = runDopplerJson(['projects', '--json']) || []
        for (const project of projects) {
            const configs = runDopplerJson([
                'configs', '--project', project.id, '--json',
            ]) || []
            for (const config of configs) scopes.push([project.id, config.name])
        }
    }

    for (const [project, config] of scopes) {
        const environment = readDopplerScope(project, config)
        if (environment) return environment
    }
    return undefined
}

const resolveEnvironment = options => {
    const explicitPath = options.env
    const candidates = [
        explicitPath,
        process.env.BABACOIFFURE_INSTAGRAM_ENV_FILE,
        findParentEnv(process.cwd()),
        ...CANONICAL_ENV_FILES,
    ].filter(Boolean)
    const envPath = candidates.map(path => resolve(path)).find(hasInstagramToken)

    const fileValues = envPath ? parseDotenv(readFileSync(envPath, 'utf8')) : {}
    const doppler = explicitPath ? undefined : findDopplerEnvironment(options)
    const values = { ...fileValues, ...process.env, ...(doppler?.values || {}) }

    if (!values.INSTAGRAM_DM_ACCESS_TOKEN) {
        throw new Error(
            'INSTAGRAM_DM_ACCESS_TOKEN was not found in Doppler or an authorized .env.'
        )
    }

    return {
        envPath,
        values,
        credentialSource: doppler?.source || (explicitPath ? 'explicit-env' : 'env-fallback'),
    }
}

const parseBoundedInteger = (value, fallback, minimum, maximum, name) => {
    if (value === undefined) return fallback
    const parsed = Number(value)

    if (!Number.isInteger(parsed) || parsed < minimum || parsed > maximum) {
        throw new Error(`${name} must be between ${minimum} and ${maximum}.`)
    }

    return parsed
}

const normalizeHandle = value => value.trim().replace(/^@/u, '').toLowerCase()

const createClient = values => {
    const baseUrl = values.INSTAGRAM_GRAPH_API_BASE_URL?.replace(/\/$/u, '')
    const version = values.INSTAGRAM_GRAPH_API_VERSION
    const token = values.INSTAGRAM_DM_ACCESS_TOKEN

    if (!baseUrl || !version || !token) {
        throw new Error('Instagram Graph API configuration is incomplete.')
    }

    const sanitize = value => String(value).split(token).join('[REDACTED]')
    const requestUrl = async url => {
        const response = await fetch(url, {
            headers: { Authorization: `Bearer ${token}` },
        })
        const body = await response.json()

        if (body.error) {
            const error = new Error(sanitize(body.error.message || 'Meta API error'))
            error.details = {
                type: body.error.type,
                code: body.error.code,
                message: sanitize(body.error.message || 'Meta API error'),
            }
            throw error
        }

        return body
    }

    const get = async (path, parameters = {}) => {
        const url = new URL(`${baseUrl}/${version}${path}`)
        for (const [key, value] of Object.entries(parameters)) {
            url.searchParams.set(key, value)
        }
        return requestUrl(url)
    }

    return { get, requestUrl }
}

const listConversations = async ({ client, limit, pages, stopWhen }) => {
    const firstPage = await client.get('/me/conversations', {
        platform: 'instagram',
        fields: 'id,updated_time,participants{id,username,name}',
        limit: String(limit),
    })
    const conversations = [...(firstPage.data || [])]
    if (stopWhen?.(conversations)) return conversations

    let next = firstPage.paging?.next
    let page = 1

    while (next && page < pages) {
        const result = await client.requestUrl(next)
        conversations.push(...(result.data || []))
        if (stopWhen?.(conversations)) return conversations

        next = result.paging?.next
        page += 1
    }

    return conversations
}

const presentParticipant = participant => ({
    id: participant.id,
    username: participant.username,
    name: participant.name,
})

const presentConversation = conversation => ({
    id: conversation.id,
    updatedTime: conversation.updated_time,
    participants: (conversation.participants?.data || []).map(presentParticipant),
})

const matchesSearch = (conversation, search) => {
    if (!search) return true
    const needle = normalizeHandle(search)
    return (conversation.participants?.data || []).some(participant =>
        `${participant.username || ''} ${participant.name || ''}`
            .toLowerCase()
            .includes(needle)
    )
}

const run = async () => {
    const options = parseArgs(process.argv.slice(2))
    if (!['account', 'conversations', 'messages'].includes(options.command)) {
        throw new Error(usage)
    }

    const { values, credentialSource } = resolveEnvironment(options)
    const client = createClient(values)
    const limit = parseBoundedInteger(options.limit, 50, 1, 100, '--limit')
    const pages = parseBoundedInteger(options.pages, 10, 1, 20, '--pages')

    if (options.command === 'account') {
        const account = await client.get('/me', { fields: 'id,username' })
        return {
            ok: true,
            account: { id: account.id, username: account.username },
            credentialSource,
            businessAccountIdConfigured: Boolean(
                values.INSTAGRAM_BUSINESS_ACCOUNT_ID
            ),
            automaticSyncEnabled:
                values.INSTAGRAM_DM_SYNC_ENABLED === 'true',
        }
    }

    if (
        options.command === 'messages' &&
        !options.username &&
        !options.conversationId
    ) {
        throw new Error('messages requires --username or --conversation-id.')
    }

    const requestedHandle = options.username
        ? normalizeHandle(options.username)
        : undefined
    const isRequestedConversation = conversation => {
        if (options.command === 'conversations') {
            return Boolean(options.search) && matchesSearch(conversation, options.search)
        }
        if (options.conversationId) {
            return conversation.id === options.conversationId
        }
        return (conversation.participants?.data || []).some(
            participant =>
                normalizeHandle(participant.username || '') === requestedHandle
        )
    }
    const conversations = await listConversations({
        client,
        limit,
        pages,
        stopWhen: items => items.some(isRequestedConversation),
    })

    if (options.command === 'conversations') {
        const matches = conversations.filter(conversation =>
            matchesSearch(conversation, options.search)
        )
        return {
            ok: true,
            search: options.search,
            count: matches.length,
            conversations: matches.map(presentConversation),
        }
    }

    const conversation = options.conversationId
        ? conversations.find(item => item.id === options.conversationId)
        : conversations.find(item =>
              (item.participants?.data || []).some(
                  participant =>
                      normalizeHandle(participant.username || '') ===
                      requestedHandle
              )
          )

    if (!conversation) {
        throw new Error('Instagram conversation not found after pagination.')
    }

    const detail = await client.get(`/${conversation.id}`, {
        fields: `messages.limit(${limit}){id,created_time,from,message}`,
    })
    const messages = (detail.messages?.data || []).slice(0, limit).map(message => {
        const presented = {
            id: message.id,
            createdTime: message.created_time,
            from:
                message.from?.username ||
                message.from?.name ||
                message.from?.id,
            hasText: typeof message.message === 'string',
            textLength:
                typeof message.message === 'string' ? message.message.length : 0,
        }

        if (options.includeText && typeof message.message === 'string') {
            presented.text = message.message
        }

        return presented
    })

    return {
        ok: true,
        conversation: presentConversation(conversation),
        includesText: Boolean(options.includeText),
        count: messages.length,
        messages,
    }
}

try {
    const result = await run()
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`)
} catch (error) {
    const details = error?.details || { message: error?.message || String(error) }
    process.stderr.write(
        `${JSON.stringify({ ok: false, error: details }, null, 2)}\n`
    )
    process.exitCode = 1
}
