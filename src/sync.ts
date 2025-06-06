import db from './db.js'
import schema from './schema.js'
import context from './context.js'
import logger from './logger.js'
import { APP_CONTEXT, SCHEMA_NAME } from './constants.js'

const MASSIVE_SYNC_THRESHOLD = 100
const MASSIVE_SYNC_BATCH = 100000

const sync = {
    terminating: false,
    prebegin: async () => {
        // update functions
        await schema.createFx()

        // attach context
        await context.attach()
        sync.begin()
    },
    begin: async (): Promise<void> => {
        if (sync.terminating) return sync.close()

        // query next block
        await db.client.query('START TRANSACTION;')
        let nextBlocks = await context.nextBlocks()
        if (!nextBlocks.first_block || !nextBlocks.last_block) {
            await db.client.query('COMMIT;')
            setTimeout(() => sync.begin(),1000)
            return
        }

        let firstBlock = nextBlocks.first_block
        let lastBlock = nextBlocks.last_block
        let count = lastBlock - firstBlock + 1
        logger.info('Blocks to sync: ['+firstBlock+','+lastBlock+'], count:',count)
        if (count > MASSIVE_SYNC_THRESHOLD) {
            await db.client.query('COMMIT;')
            await context.detach()
            logger.info('Begin massive sync')
            sync.massive(firstBlock,Math.min(firstBlock+MASSIVE_SYNC_BATCH-1,Math.floor((firstBlock+MASSIVE_SYNC_BATCH-1)/MASSIVE_SYNC_BATCH)*MASSIVE_SYNC_BATCH,lastBlock),lastBlock)
        } else {
            logger.info('Begin live sync')
            sync.live(firstBlock)
        }
    },
    massive: async (firstBlock: number, lastBlock: number ,targetBlock: number): Promise<void> => {
        if (sync.terminating) return sync.close()
        let start = new Date().getTime()
        await db.client.query('START TRANSACTION;')
        await db.client.query(`SELECT ${SCHEMA_NAME}.process_range($1,$2);`,[firstBlock,lastBlock])
        await db.client.query(`SELECT hive.app_set_current_block_num($1,$2);`,[APP_CONTEXT,lastBlock])
        await db.client.query('COMMIT;')
        let timeTaken = (new Date().getTime()-start)/1000
        logger.debug('Commited ['+firstBlock+','+lastBlock+'] successfully')
        logger.info('Massive Sync - Block #'+firstBlock+' to #'+lastBlock+' / '+targetBlock+' - '+((lastBlock-firstBlock)/timeTaken).toFixed(3)+'b/s')
        if (lastBlock >= targetBlock)
            sync.postMassive(targetBlock)
        else
            sync.massive(lastBlock+1,Math.min(lastBlock+MASSIVE_SYNC_BATCH,targetBlock),targetBlock)
    },
    postMassive: async (lastBlock: number): Promise<void> => {
        logger.info('Begin post-massive sync')
        await schema.indexCreate()
        await schema.fkCreate()
        logger.info('Post-masstive sync complete, entering live sync')
        await context.attach()
        sync.begin()
    },
    live: async (nextBlock?: number): Promise<void> => {
        if (sync.terminating) return sync.close()

        // query next blocks
        if (!nextBlock) {
            await db.client.query('START TRANSACTION;')
            nextBlock = (await context.nextBlocks()).first_block
            if (nextBlock === null) {
                await db.client.query('COMMIT;')
                setTimeout(() => sync.live(),500)
                return
            }
        }

        let start = new Date().getTime()
        await db.client.query(`SELECT ${SCHEMA_NAME}.process_range($1,$2);`,[nextBlock,nextBlock])
        await db.client.query('COMMIT;')
        let timeTakenMs = new Date().getTime()-start
        logger.info('Live Sync - Block #'+nextBlock+' - '+timeTakenMs+'ms')
        sync.live()
    },
    close: async (): Promise<void> => {
        await db.disconnect()
        process.exit(0)
    }
}

export default sync