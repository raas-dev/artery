// see the default handler for not implemented in index.ts
module.exports = {
  getUsers: async (req: any, res: any, next: any) => {
    await next()
  },
  getUserById: async (req: any, res: any, next: any) => {
    await next()
  }
}
