import type { ValidatedEventAPIGatewayProxyEvent } from '@libs/api-gateway';
import { formatJSONResponse } from '@libs/api-gateway';
import { middyfy } from '@libs/lambda';
import { MongoClient } from 'mongodb';
import schema from './schema';
import pino from 'pino-lambda';
const logger = pino();

const hello: ValidatedEventAPIGatewayProxyEvent<typeof schema> = async (event, context) => {
  logger.withRequest(event, context);

  const client = new MongoClient(process.env.DB_CONNECTION_STRING, { retryWrites: false });
  const connected = await client.connect();

  const result = await connected.db().collection('settings').insertOne({ foo: 'bar' });

  console.log('Connected successfully');
  return formatJSONResponse({
    result
  });
};

export const main = middyfy(hello);
