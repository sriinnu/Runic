/**
 * WebSocket Service
 *
 * Manages WebSocket connections for real-time updates.
 * Handles client connections, message broadcasting, and subscription management.
 *
 * Features:
 * - Client connection management
 * - Event-based message broadcasting
 * - Provider-specific subscriptions
 * - Automatic cleanup and reconnection handling
 * - Heartbeat/ping-pong for connection health
 *
 * @module services/websocket
 */

import { WebSocketServer, WebSocket } from 'ws';
import {
  WebSocketMessageType
} from '../types/index.js';
import type {
  WebSocketMessage,
  EnhancedUsageSnapshot,
  UsageAlert
} from '../types/index.js';

/**
 * Client subscription preferences
 */
interface ClientSubscription {
  providers?: string[];
  events?: WebSocketMessageType[];
  authenticated?: boolean;
  clientID: string;
}

/**
 * WebSocket client wrapper
 */
interface WebSocketClient {
  socket: WebSocket;
  subscription: ClientSubscription;
  connectedAt: Date;
  lastActivity: Date;
}

/**
 * WebSocketManager class
 *
 * Manages all WebSocket connections and provides methods for broadcasting
 * updates to connected clients based on their subscriptions.
 */
export class WebSocketManager {
  private wss: WebSocketServer;
  private clients: Map<WebSocket, WebSocketClient>;
  private heartbeatInterval: NodeJS.Timeout | null;
  private readonly HEARTBEAT_INTERVAL = 30000; // 30 seconds
  private readonly CLIENT_TIMEOUT = 60000; // 60 seconds

  /**
   * Creates a new WebSocketManager instance
   *
   * @param wss - WebSocket server instance
   */
  constructor(wss: WebSocketServer) {
    this.wss = wss;
    this.clients = new Map();
    this.heartbeatInterval = null;
    this.initialize();
  }

  /**
   * Initializes the WebSocket server and sets up event handlers
   */
  private initialize(): void {
    this.wss.on('connection', (socket: WebSocket) => {
      this.handleConnection(socket);
    });

    // Start heartbeat interval
    this.startHeartbeat();

    console.log('WebSocket manager initialized');
  }

  /**
   * Handles new WebSocket connections
   *
   * @param socket - WebSocket connection
   */
  private handleConnection(socket: WebSocket): void {
    const clientID = this.generateClientID();

    // Create client wrapper
    const client: WebSocketClient = {
      socket,
      subscription: {
        clientID,
        providers: [],
        events: Object.values(WebSocketMessageType),
        authenticated: false
      },
      connectedAt: new Date(),
      lastActivity: new Date()
    };

    this.clients.set(socket, client);

    console.log(`Client connected: ${clientID} (total: ${this.clients.size})`);

    // Send welcome message
    this.sendMessage(socket, {
      type: WebSocketMessageType.UsageUpdate,
      timestamp: new Date().toISOString(),
      data: {
        message: 'Connected to Runic API WebSocket',
        clientID
      }
    });

    // Set up event handlers
    socket.on('message', (data: Buffer) => {
      this.handleMessage(socket, data);
    });

    socket.on('close', () => {
      this.handleDisconnect(socket);
    });

    socket.on('error', (error: Error) => {
      this.handleError(socket, error);
    });

    socket.on('pong', () => {
      this.handlePong(socket);
    });
  }

  /**
   * Handles incoming messages from clients
   *
   * @param socket - WebSocket connection
   * @param data - Message data
   */
  private handleMessage(socket: WebSocket, data: Buffer): void {
    try {
      const message = JSON.parse(data.toString());
      const client = this.clients.get(socket);

      if (!client) {
        return;
      }

      client.lastActivity = new Date();

      // Handle subscription updates
      if (message.type === 'subscribe') {
        this.updateSubscription(socket, message.data);
      }

      // Handle authentication
      if (message.type === 'authenticate') {
        this.handleAuthentication(socket, message.data);
      }
    } catch (error) {
      console.error('Error handling WebSocket message:', error);
      this.sendError(socket, 'Invalid message format');
    }
  }

  /**
   * Updates client subscription preferences
   *
   * @param socket - WebSocket connection
   * @param data - Subscription data
   */
  private updateSubscription(socket: WebSocket, data: any): void {
    const client = this.clients.get(socket);
    if (!client) {
      return;
    }

    if (data.providers) {
      client.subscription.providers = data.providers;
    }

    if (data.events) {
      client.subscription.events = data.events;
    }

    console.log(`Client ${client.subscription.clientID} updated subscription:`, {
      providers: client.subscription.providers,
      events: client.subscription.events
    });

    this.sendMessage(socket, {
      type: WebSocketMessageType.UsageUpdate,
      timestamp: new Date().toISOString(),
      data: {
        message: 'Subscription updated',
        subscription: client.subscription
      }
    });
  }

  /**
   * Handles client authentication
   *
   * @param socket - WebSocket connection
   * @param _data - Authentication data (unused in mock implementation)
   */
  private handleAuthentication(socket: WebSocket, _data: any): void {
    const client = this.clients.get(socket);
    if (!client) {
      return;
    }

    // In production, validate authentication token
    // const isValid = await validateToken(data.token);

    client.subscription.authenticated = true;

    this.sendMessage(socket, {
      type: WebSocketMessageType.UsageUpdate,
      timestamp: new Date().toISOString(),
      data: {
        message: 'Authentication successful',
        authenticated: true
      }
    });
  }

  /**
   * Handles client disconnection
   *
   * @param socket - WebSocket connection
   */
  private handleDisconnect(socket: WebSocket): void {
    const client = this.clients.get(socket);
    if (client) {
      console.log(`Client disconnected: ${client.subscription.clientID}`);
      this.clients.delete(socket);
    }
  }

  /**
   * Handles WebSocket errors
   *
   * @param socket - WebSocket connection
   * @param error - Error object
   */
  private handleError(socket: WebSocket, error: Error): void {
    console.error('WebSocket error:', error);
    const client = this.clients.get(socket);
    if (client) {
      console.log(`Error for client: ${client.subscription.clientID}`);
    }
  }

  /**
   * Handles pong responses from clients
   *
   * @param socket - WebSocket connection
   */
  private handlePong(socket: WebSocket): void {
    const client = this.clients.get(socket);
    if (client) {
      client.lastActivity = new Date();
    }
  }

  /**
   * Starts the heartbeat interval to check client connections
   */
  private startHeartbeat(): void {
    this.heartbeatInterval = setInterval(() => {
      const now = Date.now();

      this.clients.forEach((client, socket) => {
        const timeSinceLastActivity = now - client.lastActivity.getTime();

        // Close inactive connections
        if (timeSinceLastActivity > this.CLIENT_TIMEOUT) {
          console.log(`Closing inactive connection: ${client.subscription.clientID}`);
          socket.terminate();
          this.clients.delete(socket);
          return;
        }

        // Send ping
        if (socket.readyState === WebSocket.OPEN) {
          socket.ping();
        }
      });
    }, this.HEARTBEAT_INTERVAL);
  }

  /**
   * Broadcasts a usage update to subscribed clients
   *
   * @param provider - Provider identifier
   * @param snapshot - Usage snapshot
   */
  public broadcastUsageUpdate(provider: string, snapshot: EnhancedUsageSnapshot): void {
    const message: WebSocketMessage = {
      type: WebSocketMessageType.UsageUpdate,
      provider,
      timestamp: new Date().toISOString(),
      data: snapshot
    };

    this.broadcast(message, (client) => {
      const subscribedToProvider = !client.subscription.providers?.length ||
        client.subscription.providers.includes(provider);
      const subscribedToEvent = client.subscription.events?.includes(WebSocketMessageType.UsageUpdate) ?? true;

      return subscribedToProvider && subscribedToEvent;
    });
  }

  /**
   * Broadcasts an alert to subscribed clients
   *
   * @param alert - Usage alert
   */
  public broadcastAlert(alert: UsageAlert): void {
    const message: WebSocketMessage = {
      type: WebSocketMessageType.AlertCreated,
      provider: alert.provider,
      timestamp: new Date().toISOString(),
      data: alert
    };

    this.broadcast(message, (client) => {
      const subscribedToProvider = !client.subscription.providers?.length ||
        client.subscription.providers.includes(alert.provider);
      const subscribedToEvent = client.subscription.events?.includes(WebSocketMessageType.AlertCreated) ?? true;

      return subscribedToProvider && subscribedToEvent;
    });
  }

  /**
   * Broadcasts a message to all matching clients
   *
   * @param message - WebSocket message
   * @param filter - Optional filter function to determine which clients receive the message
   */
  private broadcast(message: WebSocketMessage, filter?: (client: WebSocketClient) => boolean): void {
    const messageStr = JSON.stringify(message);
    let sentCount = 0;

    this.clients.forEach((client, socket) => {
      if (filter && !filter(client)) {
        return;
      }

      if (socket.readyState === WebSocket.OPEN) {
        socket.send(messageStr);
        sentCount++;
      }
    });

    console.log(`Broadcast ${message.type} to ${sentCount} clients`);
  }

  /**
   * Sends a message to a specific client
   *
   * @param socket - WebSocket connection
   * @param message - WebSocket message
   */
  private sendMessage(socket: WebSocket, message: WebSocketMessage): void {
    if (socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify(message));
    }
  }

  /**
   * Sends an error message to a client
   *
   * @param socket - WebSocket connection
   * @param error - Error message
   */
  private sendError(socket: WebSocket, error: string): void {
    this.sendMessage(socket, {
      type: WebSocketMessageType.UsageUpdate,
      timestamp: new Date().toISOString(),
      data: {
        error
      }
    });
  }

  /**
   * Generates a unique client ID
   *
   * @returns Client ID string
   */
  private generateClientID(): string {
    return `client_${Date.now()}_${Math.random().toString(36).substring(7)}`;
  }

  /**
   * Gets the number of connected clients
   *
   * @returns Number of connected clients
   */
  public getClientCount(): number {
    return this.clients.size;
  }

  /**
   * Closes all connections and shuts down the WebSocket manager
   */
  public shutdown(): void {
    console.log('Shutting down WebSocket manager...');

    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }

    this.clients.forEach((_client, socket) => {
      socket.close(1001, 'Server shutting down');
    });

    this.clients.clear();
    console.log('WebSocket manager shut down');
  }
}
